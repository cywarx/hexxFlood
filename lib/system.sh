#!/usr/bin/env bash
# ============================================================
# hexxFlood :: lib/system.sh
# Host-side tuning and privilege handling: reversible sysctl /
# tx-queue / governor tuning, GOD MODE kernel limits, and the
# root-elevation flow. Everything here is restored on cleanup.
# ============================================================

apply_system_tuning() {
    [ "$SYS_TUNE" = true ] || return 0
    TUNING_APPLIED=1

    if [ -f "/sys/class/net/$INTERFACE/tx_queue_len" ]; then
        SAVED_TXQLEN=$(cat "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null)
        sudo ip link set dev "$INTERFACE" txqueuelen "$TX_QUEUE_LEN" 2>/dev/null || true
    fi

    local k
    for k in net.core.wmem_max net.core.rmem_max net.core.netdev_max_backlog; do
        SAVED_SYSCTL["$k"]=$(sysctl -n "$k" 2>/dev/null)
    done
    sudo sysctl -qw net.core.wmem_max=134217728 2>/dev/null || true
    sudo sysctl -qw net.core.rmem_max=134217728 2>/dev/null || true
    sudo sysctl -qw net.core.netdev_max_backlog=250000 2>/dev/null || true

    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        SAVED_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
        local g
        for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo performance | sudo tee "$g" >/dev/null 2>&1 || true
        done
    fi

    ulimit -n 65535 2>/dev/null || true

    echo -e "${GREEN}⚙️  System tuning applied${NC}"
    log_attack "System tuning applied (tx-queue: $TX_QUEUE_LEN)"
    return 0
}

restore_system_tuning() {
    [ "${TUNING_APPLIED:-0}" = 1 ] || return 0

    [ -n "${SAVED_TXQLEN:-}" ] && \
        sudo ip link set dev "$INTERFACE" txqueuelen "$SAVED_TXQLEN" 2>/dev/null || true

    local k
    for k in "${!SAVED_SYSCTL[@]}"; do
        [ -n "${SAVED_SYSCTL[$k]}" ] && sudo sysctl -qw "$k=${SAVED_SYSCTL[$k]}" 2>/dev/null || true
    done

    if [ -n "${SAVED_GOVERNOR:-}" ]; then
        local g
        for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "$SAVED_GOVERNOR" | sudo tee "$g" >/dev/null 2>&1 || true
        done
    fi
    log_attack "System tuning restored"
    return 0
}

god_mode_optimization() {
    echo -e "${BOLD}${RED}☢️  ACTIVATING GOD MODE OPTIMIZATIONS ☢️${NC}"
    
    ulimit -n 1048576 2>/dev/null || true
    ulimit -u unlimited 2>/dev/null || true
    ulimit -m unlimited 2>/dev/null || true
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance | sudo tee "$cpu" >/dev/null 2>&1 || true
    done
    
    sysctl -w net.core.rmem_max=67108864 2>/dev/null || true
    sysctl -w net.core.wmem_max=67108864 2>/dev/null || true
    sysctl -w net.core.netdev_max_backlog=500000 2>/dev/null || true
    sysctl -w net.ipv4.tcp_rmem="4096 87380 67108864" 2>/dev/null || true
    sysctl -w net.ipv4.tcp_wmem="4096 65536 67108864" 2>/dev/null || true
    
    echo -e "${GREEN}✅ GOD MODE optimizations applied${NC}"
    log_attack "God mode optimizations applied"
}

# ---- privilege management ----------------------------------

ensure_privileges() {
    if [ "$EUID" -eq 0 ]; then
        RUN_AS_ROOT=1
        return 0
    fi
    RUN_AS_ROOT=0

    [ "$RUN_MONITOR_ONLY" = true ] && return 0

    local has_http=0
    if [ "$TARGET_TYPE" = "url" ] || [[ ",$ATTACK_TYPES," == *",http,"* ]]; then
        has_http=1
    fi

    local needs_root=0
    if echo ",$ATTACK_TYPES," | grep -qE ',(syn|udp|icmp|ack|rst|fin),'; then
        needs_root=1
    fi
    
    if [ "$needs_root" -eq 0 ] && [ "$has_http" -eq 1 ]; then
        echo -e "${GREEN}✅ Running without root (HTTP flood only)${NC}"
        RUN_AS_ROOT=0
        SYS_TUNE=false
        return 0
    fi

    echo -e "${YELLOW}🔐 Root privileges needed for raw-packet attacks.${NC}"
    echo ""

    local ans=""
    case "${AUTO_ROOT,,}" in
        1|y|yes|true)
            ans="y" ;;
        0|n|no|false)
            ans="n" ;;
        *)
            read -r -p "$(echo -e "${WHITE}Run as root? [Y/n]: ${NC}")" ans </dev/tty 2>/dev/null || ans="y"
            ;;
    esac

    case "${ans,,}" in
        n|no)
            if [ "$needs_root" -eq 1 ]; then
                echo -e "${RED}❌ Raw-packet attack needs root.${NC}"
                echo -e "${YELLOW}   Re-run with: sudo $0 $*${NC}"
                exit 1
            fi
            echo -e "${YELLOW}⚠️  Running without root: HTTP flood only.${NC}"
            SYS_TUNE=false
            RUN_AS_ROOT=0
            ;;
        *)
            echo -e "${CYAN}🔼 Elevating with sudo...${NC}"
            exec sudo -E bash "$0" "${SCRIPT_ARGS[@]}"
            ;;
    esac
}
