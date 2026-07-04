#!/usr/bin/env bash
# ============================================================
# hexxFlood :: lib/dashboard.sh
# Live in-terminal dashboard (monitor_attack), the end-of-run
# report generator, the cleanup/teardown handler, and the
# auto-launch of external monitor windows. This is the IN-PROCESS
# dashboard shown during an attack. NOT to be confused with the
# standalone monitor.sh at the repo root, which is a separate
# program launched in its own terminal window.
# ============================================================

generate_report() {
    if [ "$ENABLE_REPORTING" != true ]; then
        return 0
    fi
    
    echo -e "${CYAN}📊 Generating attack report...${NC}"

    local report
    report=$(cat << EOF
========================================
    HEXXFLOOD ATTACK REPORT
========================================
Generated: $(date)

TARGET INFORMATION
------------------
Target IP: $TARGET
Target Type: $TARGET_TYPE
URL: ${URL:-N/A}
Port: ${TARGET_PORT:-80}

ATTACK CONFIGURATION
-------------------
Mode: ${MODE:-custom}
Duration: ${ATTACK_DURATION:-Infinite}
Threads: $THREADS
Packet Size: $PACKET_SIZE
Attack Types: $ATTACK_TYPES
Interface: $INTERFACE
Spoofing: $SPOOF_IP

PERFORMANCE STATISTICS
---------------------
Total Packets Sent: $(printf "%'d" "$TOTAL_PACKETS_SENT")
Total Bytes Sent: $(printf "%'d" "$TOTAL_BYTES_SENT")
Peak PPS: $(printf "%'d" "$PEAK_PPS")
Average PPS: $(printf "%'d" "$AVG_PPS")
Attack Duration: ${ATTACK_DURATION_SECONDS}s

SYSTEM INFORMATION
-----------------
CPU Cores: $CORES
Interface: $INTERFACE

========================================
EOF
)

    # Write, verifying success. The default /tmp path can be owned by root from
    # an earlier elevated run; if we can't write it, fall back to a per-user file
    # and only claim success when a write actually lands — never report a lie.
    mkdir -p "$(dirname "$REPORT_FILE" 2>/dev/null)" 2>/dev/null || true
    # 2>/dev/null is placed BEFORE the > redirect so a failed open (e.g. a
    # root-owned target file) is silenced too — order matters here.
    if printf '%s\n' "$report" 2>/dev/null >"$REPORT_FILE"; then
        echo -e "${GREEN}✅ Report saved to: $REPORT_FILE${NC}"
        log_attack "Report generated: $REPORT_FILE"
    else
        local fallback="${HOME:-/tmp}/.hexxflood_report.txt"
        if printf '%s\n' "$report" 2>/dev/null >"$fallback"; then
            REPORT_FILE="$fallback"
            echo -e "${YELLOW}⚠️  Default report path not writable — saved to: $fallback${NC}"
            log_attack "Report generated (fallback): $fallback"
        else
            echo -e "${RED}❌ Could not write report (no writable path).${NC}"
            log_attack "Report generation FAILED" "WARN"
        fi
    fi
    return 0
}

# ---- live dashboard ----------------------------------------

monitor_attack() {
    local start_time=${ATTACK_START_TIME:-$(date +%s)}
    local initial_packets=${ATTACK_INITIAL_PACKETS:-$(get_packet_count)}
    local initial_bytes=$(get_tx_bytes)
    local duration=$ATTACK_DURATION
    
    ATTACK_START_TIME=$start_time
    ATTACK_INITIAL_PACKETS=$initial_packets
    
    local dur_disp="∞"; [ "$duration" -gt 0 ] && dur_disp="${duration}s"
    local tgt_disp="$TARGET"
    [ "$TARGET_TYPE" = "url" ] && tgt_disp="$URL  (${TARGET})"
    
    DASHBOARD_ACTIVE=1
    local HOME_C='' CLR_BELOW=''
    ( stty sane </dev/tty ) >/dev/null 2>&1 || true
    if [ -t 1 ]; then
        printf '\033[?1049h\033[?25l\033[?7l\033[H\033[2J'
        HOME_C='\033[H'; CLR_BELOW='\033[J'
        ALT_SCREEN=1
        printf '%b\r\n' "${WHITE}☢️  hexxFlood LIVE — monitoring attack...${NC}"
    fi
    
    cpu_busy_pct >/dev/null
    local prev_packets=$initial_packets prev_bytes=$initial_bytes prev_time=$start_time
    local pps_max=1
    local -a evlog=()
    
    while true; do
        local now=$(date +%s)
        local elapsed=$(( now - start_time ))
        
        if [ $duration -gt 0 ] && [ $elapsed -ge $duration ]; then
            break
        fi
        
        local cur_packets=$(get_packet_count)
        local cur_bytes=$(get_tx_bytes)
        local packets_sent=$(( cur_packets - initial_packets ))
        [ $packets_sent -lt 0 ] && packets_sent=0
        
        TOTAL_PACKETS_SENT=$packets_sent
        TOTAL_BYTES_SENT=$(( cur_bytes - initial_bytes ))
        
        local dt=$(( now - prev_time )); [ $dt -le 0 ] && dt=1
        local dpkts=$(( cur_packets - prev_packets )); [ $dpkts -lt 0 ] && dpkts=0
        local dbytes=$(( cur_bytes - prev_bytes )); [ $dbytes -lt 0 ] && dbytes=0
        local pps=$(( dpkts / dt ))
        local avg=0; [ $elapsed -gt 0 ] && avg=$(( packets_sent / elapsed ))
        local bps=$(( (dbytes / dt) * 8 ))
        prev_packets=$cur_packets; prev_bytes=$cur_bytes; prev_time=$now
        [ $pps -gt $pps_max ] && pps_max=$pps
        PEAK_PPS=$pps_max
        AVG_PPS=$avg
        ATTACK_DURATION_SECONDS=$elapsed
        
        local hcount=0
        hcount=$(pgrep -c hping3 2>/dev/null || echo 0)
        local httpc=0
        httpc=$(pgrep -cf http_flood.py 2>/dev/null || echo 0)
        
        local cpu=$(cpu_busy_pct)
        local mem=$(mem_used_str)
        local conns=$(ss -tan 2>/dev/null | grep -c ESTAB || echo 0)
        
        local cols; cols=$(tput cols 2>/dev/null); [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
        local barw=$(( cols - 40 )); [ $barw -gt 40 ] && barw=40; [ $barw -lt 10 ] && barw=10
        local div; div=$(printf '─%.0s' $(seq 1 $(( cols>80?80:cols )) ))
        local bar; bar=$(draw_bar "$pps" "$pps_max" "$barw")
        
        { printf "$HOME_C"
          pln "${RED}☢️  hexxFlood LIVE  ${NC}${CYAN}$(date +%H:%M:%S)${NC}"
          pln "${CYAN}${div}${NC}"
          pln "${YELLOW}🎯 Target :${NC} ${WHITE}${tgt_disp}${NC}"
          pln "${YELLOW}⏱️  Time   :${NC} ${WHITE}${elapsed}s${NC}  (${dur_disp})"
          pln "${CYAN}${div}${NC}"
          pln "${YELLOW}📦 Packets:${NC} ${WHITE}$(printf "%'d" "$packets_sent")${NC} sent"
          pln "${YELLOW}⚡ Live   :${NC} ${GREEN}$(printf "%'d" "$pps")${NC} pps  ${CYAN}[${bar}]${NC}"
          pln "${YELLOW}📈 Avg    :${NC} ${WHITE}$(printf "%'d" "$avg")${NC} pps      ${YELLOW}🌐 TX:${NC} ${WHITE}$(fmt_bps "$bps")${NC}"
          pln "${YELLOW}🖥️  Host   :${NC} cpu ${WHITE}${cpu}%${NC}  mem ${WHITE}${mem}${NC}"
          pln "${CYAN}${div}${NC}"
          pln "${YELLOW}🧨 hping3 :${NC} ${WHITE}${hcount}${NC} procs   ${YELLOW}http:${NC} ${WHITE}${httpc}${NC}"
          pln "${RED}Press Ctrl+C to stop${NC}"
          printf "$CLR_BELOW"
        }
        
        sleep 1
    done
    
    cleanup
}

# ---- teardown / cleanup ------------------------------------

cleanup() {
    trap '' SIGINT SIGTERM
    [ "${CLEANUP_DONE:-0}" = 1 ] && exit 0
    CLEANUP_DONE=1
    
    echo -e "\n${YELLOW}🛑 Stopping attack...${NC}"
    
    ( stty sane </dev/tty ) >/dev/null 2>&1 || true
    
    [ "${ALT_SCREEN:-0}" = 1 ] && printf '\033[?1049l' 2>/dev/null
    printf '\033[?7h\033[?25h\033[0m\r' 2>/dev/null
    tput cnorm 2>/dev/null
    
    disown -a 2>/dev/null || true
    
    # Kill all attack processes. hping3 is always root-owned (sudo). The Python
    # floods run as the invoking user on the no-root HTTP path, so kill them with
    # a plain pkill FIRST (works without a password) and then with sudo to also
    # catch the root-owned copies when the whole run was elevated.
    local proc
    {
        for proc in hping3 http_flood.py http2_flood.py websocket_flood.py \
                    graphql_flood.py ssl_reneg.py slowloris.py dns_flood.py api_server.py; do
            pkill -9 -f "$proc" 2>/dev/null
            sudo -n pkill -9 -f "$proc" 2>/dev/null
        done
    } >/dev/null 2>&1

    # Legacy cleanup: older versions generated the flood scripts in /tmp; the
    # payloads now ship in payloads/ and are never copied to /tmp, but sweep any
    # stale /tmp copies left by a pre-upgrade run (harmless if none exist).
    rm -f /tmp/*_flood.py /tmp/*_reneg.py /tmp/*loris.py /tmp/api_server.py 2>/dev/null
    sudo -n rm -f /tmp/*_flood.py /tmp/*_reneg.py /tmp/*loris.py /tmp/api_server.py 2>/dev/null
    
    restore_system_tuning
    
    # Generate report
    generate_report
    
    local elapsed=0 total=0 avg=0
    if [ -n "${ATTACK_START_TIME:-}" ]; then
        elapsed=$(( $(date +%s) - ATTACK_START_TIME ))
        total=$(( $(get_packet_count) - ${ATTACK_INITIAL_PACKETS:-0} ))
        [ "$elapsed" -gt 0 ] && avg=$(( total / elapsed ))
    fi
    
    pl() { printf '%b\r\n' "$1"; }
    
    pl ""
    pl "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    pl "${BOLD}${RED}☢️  ATTACK COMPLETED ☢️${NC}"
    pl "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    pl ""
    pl "${GREEN}✅ All attack processes terminated${NC}"
    pl "${GREEN}✅ Temporary files removed${NC}"
    [ "${TUNING_APPLIED:-0}" = 1 ] && pl "${GREEN}✅ System settings restored${NC}"
    pl ""
    if [ -n "${ATTACK_START_TIME:-}" ]; then
        pl "${YELLOW}📊 FINAL STATISTICS${NC}"
        pl "   ${WHITE}Total Packets Sent : ${GREEN}$(printf "%'d" "$total")${NC}"
        pl "   ${WHITE}Total Attack Time  : ${GREEN}${elapsed}s${NC}"
        pl "   ${WHITE}Average PPS        : ${GREEN}$(printf "%'d" "$avg")${NC}"
        pl "   ${WHITE}Peak PPS           : ${GREEN}$(printf "%'d" "$PEAK_PPS")${NC}"
        pl ""
    fi
    pl "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    pl "${GREEN}✅ Cleanup complete. Stay ethical. 👋${NC}"
    pl ""
    
    log_attack "Attack stopped. Total packets: $total, Duration: ${elapsed}s"
    exit 0
}

# ---- external monitor windows ------------------------------

resolve_display() {
    local real_user="${SUDO_USER:-$USER}"
    MON_HOME=$(getent passwd "$real_user" | cut -d: -f6 2>/dev/null)
    MON_HOME="${MON_HOME:-$HOME}"

    if [ -n "$DISPLAY" ]; then
        MON_DISPLAY="$DISPLAY"
    else
        MON_DISPLAY=$(who 2>/dev/null | grep -oE '\(:[0-9]+(\.[0-9]+)?\)' | tr -d '()' | head -1)
    fi
}

launch_one_monitor() {
    local mode="$1"
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        return 1
    fi
    
    resolve_display
    if [ -z "$MON_DISPLAY" ]; then
        return 1
    fi
    
    if command -v xterm &>/dev/null; then
        DISPLAY="$MON_DISPLAY" xterm -T "hexxFlood Monitor [$mode]" -e bash "$MONITOR_SCRIPT" -t "$TARGET" -i "$INTERFACE" -m "$mode" &
        return 0
    elif command -v gnome-terminal &>/dev/null; then
        DISPLAY="$MON_DISPLAY" gnome-terminal --title "hexxFlood Monitor [$mode]" -- bash "$MONITOR_SCRIPT" -t "$TARGET" -i "$INTERFACE" -m "$mode" &
        return 0
    elif command -v konsole &>/dev/null; then
        DISPLAY="$MON_DISPLAY" konsole -p "tabtitle=hexxFlood Monitor [$mode]" -e bash "$MONITOR_SCRIPT" -t "$TARGET" -i "$INTERFACE" -m "$mode" &
        return 0
    fi
    
    return 1
}

launch_monitors() {
    [ "$AUTO_MONITOR" = true ] || return 0
    launch_one_monitor "$MONITOR_MODE" 2>/dev/null
}
