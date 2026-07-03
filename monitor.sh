#!/bin/bash

# ============================================================
# hexxFlood - Monitoring Script
# Version: 1.0
# ============================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ---- Terminal control -------------------------------------------------------
NOWRAP='\033[?7l'    # disable line wrap: long lines are clipped, never wrapped
WRAP='\033[?7h'      # re-enable line wrap
CLR_ALL='\033[2J'    # clear whole screen
HOME='\033[H'        # cursor to top-left

hide_cursor() { tput civis 2>/dev/null; }
show_cursor() { tput cnorm 2>/dev/null; }

# Current terminal height in rows (fallback 24 if unreadable)
term_rows() {
    local r; r=$(tput lines 2>/dev/null)
    if [[ "$r" =~ ^[0-9]+$ ]] && [ "$r" -gt 0 ]; then echo "$r"; else echo 24; fi
}

# Prepare the screen for live, in-place rendering
screen_init() {
    hide_cursor
    printf "${NOWRAP}${CLR_ALL}${HOME}"
}

# Restore the terminal to normal on exit
screen_done() {
    printf "${WRAP}"
    show_cursor
}

# Update EXACTLY ONE row in place: jump to row $1, print $2, clear to line end.
# This is what makes values update live without repainting the whole screen.
put() { printf "\033[${1};1H%b\033[K" "$2"; }

# ---- Default values ---------------------------------------------------------
TARGET="192.168.1.14"
INTERFACE="wlan0"
MONITOR_MODE="full"
REFRESH="1"          # seconds between updates (lower = more real-time)
NEED_REDRAW=0        # set by SIGWINCH so a resize repaints the static layout

# Convert a bytes/sec figure into a human-readable rate
human_rate() {
    local b=$1
    if   [ "$b" -ge 1073741824 ]; then awk "BEGIN{printf \"%.2f GB/s\", $b/1073741824}"
    elif [ "$b" -ge 1048576 ];    then awk "BEGIN{printf \"%.2f MB/s\", $b/1048576}"
    elif [ "$b" -ge 1024 ];       then awk "BEGIN{printf \"%.2f KB/s\", $b/1024}"
    else echo "${b} B/s"
    fi
}

# Read cumulative RX/TX byte counters for the interface (fast, from /sys)
read_bytes() {
    local iface=$1
    RX_NOW=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
    TX_NOW=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
}

# Compute live RX/TX rates (B/s) from byte deltas over the ACTUAL elapsed time.
# Sets RX_RATE / TX_RATE and rolls the previous sample forward.
calc_rates() {
    read_bytes "$INTERFACE"; TS_NOW=$(date +%s.%N)
    RX_RATE=$(awk "BEGIN{dt=$TS_NOW-$TS_PREV; if(dt<=0)dt=$REFRESH; r=($RX_NOW-$RX_PREV)/dt; if(r<0)r=0; printf \"%d\", r}")
    TX_RATE=$(awk "BEGIN{dt=$TS_NOW-$TS_PREV; if(dt<=0)dt=$REFRESH; r=($TX_NOW-$TX_PREV)/dt; if(r<0)r=0; printf \"%d\", r}")
    RX_PREV=$RX_NOW; TX_PREV=$TX_NOW; TS_PREV=$TS_NOW
}

# Show banner (one-off, used by help/standalone)
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║   ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗    ║"
    echo "║   ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗   ║"
    echo "║   ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝   ║"
    echo "║   ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗   ║"
    echo "║   ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║   ║"
    echo "║   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ║"
    echo "║                                                                  ║"
    echo "║              hexxFlood - Monitoring Script v1.0                  ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║                       Author: CyWarX                             ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Paint the banner starting at the current cursor position (15 rows tall)
draw_banner_at_top() {
    printf "${HOME}"
    echo -e "${CYAN}\033[K"
    echo -e "╔══════════════════════════════════════════════════════════════════╗\033[K"
    echo -e "║                                                                  ║\033[K"
    echo -e "║   ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗    ║\033[K"
    echo -e "║   ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗   ║\033[K"
    echo -e "║   ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝   ║\033[K"
    echo -e "║   ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗   ║\033[K"
    echo -e "║   ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║   ║\033[K"
    echo -e "║   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ║\033[K"
    echo -e "║                                                                  ║\033[K"
    echo -e "║              hexxFlood - Monitoring Script v1.0                  ║\033[K"
    echo -e "╠══════════════════════════════════════════════════════════════════╣\033[K"
    echo -e "║                       Author: CyWarX                             ║\033[K"
    echo -e "╚══════════════════════════════════════════════════════════════════╝\033[K"
    echo -e "${NC}\033[K"
}

# Show help
show_help() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}📖 hexxFlood - Monitor Script Help${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./monitor.sh [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  -t, --target IP       Target IP to monitor (default: 192.168.1.14)"
    echo "  -i, --interface IFACE Network interface (default: wlan0)"
    echo "  -m, --mode MODE       Monitor mode: ping|network|system|full|log"
    echo "  -r, --refresh SEC     Update interval in seconds (default: 1, e.g. 0.5)"
    echo "  -h, --help            Show this help"
    echo ""
    echo -e "${YELLOW}Monitor Modes:${NC}"
    echo "  ping     - Only ping monitoring"
    echo "  network  - Network traffic monitoring"
    echo "  system   - System resources monitoring"
    echo "  full     - All monitoring (default)"
    echo "  log      - Save to log file"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ./monitor.sh -t 192.168.1.14 -m full"
    echo "  ./monitor.sh -t 192.168.1.10 -m ping"
    echo "  ./monitor.sh -i eth0 -m network"
    echo "  ./monitor.sh -t 192.168.1.14 -m log"
    echo ""
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target)    TARGET="$2";       shift 2 ;;
            -i|--interface) INTERFACE="$2";    shift 2 ;;
            -m|--mode)      MONITOR_MODE="$2"; shift 2 ;;
            -r|--refresh)   REFRESH="$2";      shift 2 ;;
            -h|--help)      show_help; exit 0 ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================================================
#  PING MODE
# ============================================================================
draw_static_ping() {
    printf "${CLR_ALL}"
    CUR=1
    put $((CUR++)) "${GREEN}📊 Live ping tracking: ${WHITE}$TARGET${NC}"
    put $((CUR++)) "${YELLOW}Press Ctrl+C to stop   (updates every ${REFRESH}s)${NC}"
    put $((CUR++)) ""
    put $((CUR++)) "${CYAN}${SEP}${NC}"
    ROW_STATUS=$((CUR++))
    ROW_REPLY=$((CUR++))
    put $((CUR++)) "${CYAN}${SEP}${NC}"
    ROW_TIME=$((CUR++))
}

monitor_ping() {
    screen_init
    draw_static_ping
    trap 'NEED_REDRAW=1' SIGWINCH

    while true; do
        [ "$NEED_REDRAW" = 1 ] && { NEED_REDRAW=0; screen_init; draw_static_ping; }

        if PING_LINE=$(ping -c 1 -W 1 "$TARGET" 2>/dev/null | grep -E "bytes from"); then
            LAT=$(echo "$PING_LINE" | grep -o "time=[0-9.]* ms")
            put "$ROW_STATUS" "${GREEN}✅ ALIVE${NC}   ${YELLOW}Latency:${NC} ${WHITE}${LAT:-n/a}${NC}"
            put "$ROW_REPLY"  "${PING_LINE}"
        else
            put "$ROW_STATUS" "${RED}💀 TARGET UNRESPONSIVE!${NC}"
            put "$ROW_REPLY"  ""
        fi
        put "$ROW_TIME" "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)${NC}"
        sleep "$REFRESH"
    done
}

# ============================================================================
#  NETWORK MODE
# ============================================================================
draw_static_network() {
    printf "${CLR_ALL}"
    CUR=1
    put $((CUR++)) "${GREEN}📡 Live network tracking: ${WHITE}$INTERFACE${NC}"
    put $((CUR++)) "${YELLOW}Press Ctrl+C to stop   (updates every ${REFRESH}s)${NC}"
    put $((CUR++)) ""
    put $((CUR++)) "${CYAN}${SEP}${NC}"
    put $((CUR++)) "${WHITE}📡 THROUGHPUT (live)${NC}"
    put $((CUR++)) "${CYAN}${SEP}${NC}"
    ROW_RX=$((CUR++))
    ROW_TX=$((CUR++))
    put $((CUR++)) ""
    ROW_NET0=$((CUR++))
    ROW_NET1=$((CUR++))
    put $((CUR++)) ""
    ROW_CONN=$((CUR++))
    ROW_HPING=$((CUR++))
    put $((CUR++)) ""
    ROW_TIME=$((CUR++))
}

monitor_network() {
    screen_init
    read_bytes "$INTERFACE"; RX_PREV=$RX_NOW; TX_PREV=$TX_NOW; TS_PREV=$(date +%s.%N)
    draw_static_network
    trap 'NEED_REDRAW=1' SIGWINCH

    while true; do
        [ "$NEED_REDRAW" = 1 ] && { NEED_REDRAW=0; screen_init; draw_static_network; }

        calc_rates
        mapfile -t NET < <(ifconfig "$INTERFACE" 2>/dev/null | grep -E "TX packets|RX packets")
        CONNECTIONS=$(netstat -an 2>/dev/null | grep -c ESTABLISHED)
        HPING_COUNT=$(pgrep -c hping3 2>/dev/null || echo 0)

        put "$ROW_RX"    "${YELLOW}⬇️  RX Rate:${NC} ${WHITE}$(human_rate "$RX_RATE")${NC}"
        put "$ROW_TX"    "${YELLOW}⬆️  TX Rate:${NC} ${WHITE}$(human_rate "$TX_RATE")${NC}"
        put "$ROW_NET0"  "${NET[0]}"
        put "$ROW_NET1"  "${NET[1]}"
        put "$ROW_CONN"  "${YELLOW}Active Connections:${NC} ${WHITE}$CONNECTIONS${NC}"
        put "$ROW_HPING" "${YELLOW}hping3 Processes:${NC} ${WHITE}$HPING_COUNT${NC}"
        put "$ROW_TIME"  "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)${NC}"
        sleep "$REFRESH"
    done
}

# ============================================================================
#  SYSTEM MODE
# ============================================================================
draw_static_system() {
    printf "${CLR_ALL}"
    CUR=1
    put $((CUR++)) "${GREEN}💻 Live system tracking${NC}"
    put $((CUR++)) "${YELLOW}Press Ctrl+C to stop   (updates every ${REFRESH}s)${NC}"
    put $((CUR++)) ""
    put $((CUR++)) "${CYAN}${SEP}${NC}"
    put $((CUR++)) "${WHITE}💻 SYSTEM RESOURCES${NC}"
    put $((CUR++)) "${CYAN}${SEP}${NC}"
    ROW_CPU=$((CUR++))
    ROW_MEM=$((CUR++))
    ROW_LOAD=$((CUR++))
    put $((CUR++)) ""
    put $((CUR++)) "${YELLOW}Attack Processes:${NC}"
    ROW_HPING=$((CUR++))
    ROW_HTTP=$((CUR++))
    put $((CUR++)) ""
    put $((CUR++)) "${YELLOW}Top CPU Processes:${NC}"
    ROW_TOP=()
    for _ in 1 2 3 4 5; do ROW_TOP+=("$((CUR++))"); done
    put $((CUR++)) ""
    ROW_TIME=$((CUR++))
}

monitor_system() {
    screen_init
    draw_static_system
    trap 'NEED_REDRAW=1' SIGWINCH

    while true; do
        [ "$NEED_REDRAW" = 1 ] && { NEED_REDRAW=0; screen_init; draw_static_system; }

        CPU=$(top -bn1 | grep -m1 Cpu | awk '{print $2}')
        MEM=$(free -h | awk '/Mem/{print $3 "/" $2}')
        LOAD=$(uptime | awk -F'load average:' '{print $2}')
        HPING_COUNT=$(pgrep -c hping3 2>/dev/null || echo 0)
        HTTP_COUNT=$(pgrep -fc http_flood.py 2>/dev/null || echo 0)
        mapfile -t TOPP < <(ps aux --sort=-%cpu | head -6 | tail -5 | awk '{print "  " $11 " - " $3 "%"}')

        put "$ROW_CPU"   "${YELLOW}CPU Usage:${NC} ${WHITE}${CPU:-0}%${NC}"
        put "$ROW_MEM"   "${YELLOW}Memory:${NC} ${WHITE}$MEM${NC}"
        put "$ROW_LOAD"  "${YELLOW}Load Average:${NC}${WHITE}$LOAD${NC}"
        put "$ROW_HPING" "  hping3: ${WHITE}$HPING_COUNT${NC}"
        put "$ROW_HTTP"  "  HTTP:   ${WHITE}$HTTP_COUNT${NC}"
        for i in 0 1 2 3 4; do put "${ROW_TOP[$i]}" "${TOPP[$i]}"; done
        put "$ROW_TIME"  "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)${NC}"
        sleep "$REFRESH"
    done
}

# ============================================================================
#  FULL MODE  (default dashboard)
# ============================================================================
draw_static_full() {
    local rows; rows=$(term_rows)
    SHOW_BANNER=0; [ "$rows" -ge 40 ] && SHOW_BANNER=1

    printf "${CLR_ALL}"
    CUR=1
    if [ "$SHOW_BANNER" = 1 ]; then
        draw_banner_at_top
        CUR=16
    fi
    put $((CUR++)) "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    put $((CUR++)) "${WHITE}                    ☢️  hexxFlood MONITOR  ☢️${NC}"
    put $((CUR++)) "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    put $((CUR++)) ""
    put $((CUR++)) "${YELLOW}📍 TARGET:${NC} ${WHITE}$TARGET${NC}"
    ROW_RESP=$((CUR++))
    put $((CUR++)) ""
    put $((CUR++)) "${YELLOW}📡 NETWORK ($INTERFACE):${NC}"
    ROW_RATE=$((CUR++))
    ROW_NET0=$((CUR++))
    ROW_NET1=$((CUR++))
    put $((CUR++)) ""
    put $((CUR++)) "${YELLOW}🔢 Active Processes:${NC}"
    ROW_HPING=$((CUR++))
    ROW_HTTP=$((CUR++))
    put $((CUR++)) ""
    ROW_CPU=$((CUR++))
    ROW_MEM=$((CUR++))
    ROW_LOAD=$((CUR++))
    put $((CUR++)) ""
    put $((CUR++)) "${CYAN}${SEP}${NC}"
    ROW_TIME=$((CUR++))
    put $((CUR++)) "${CYAN}${SEP}${NC}"
    put $((CUR++)) "${RED}Press Ctrl+C to stop monitoring${NC}   (refresh: every ${REFRESH}s)"
}

monitor_full() {
    screen_init
    read_bytes "$INTERFACE"; RX_PREV=$RX_NOW; TX_PREV=$TX_NOW; TS_PREV=$(date +%s.%N)
    draw_static_full
    trap 'NEED_REDRAW=1' SIGWINCH

    while true; do
        [ "$NEED_REDRAW" = 1 ] && { NEED_REDRAW=0; screen_init; draw_static_full; }

        calc_rates
        PING_RESULT=$(ping -c 1 -W 1 "$TARGET" 2>/dev/null | grep -o "time=[0-9.]* ms" | head -1)
        if [ -z "$PING_RESULT" ]; then PING_RESULT="${RED}💀 TARGET UNRESPONSIVE!${NC}"
        else PING_RESULT="${GREEN}$PING_RESULT${NC}"; fi
        mapfile -t NET < <(ifconfig "$INTERFACE" 2>/dev/null | grep -E "TX packets|RX packets")
        HPING_COUNT=$(pgrep -c hping3 2>/dev/null || echo 0)
        HTTP_COUNT=$(pgrep -fc http_flood.py 2>/dev/null || echo 0)
        CPU=$(top -bn1 | grep -m1 Cpu | awk '{print $2}')
        MEM=$(free -h | awk '/Mem/{print $3 "/" $2}')
        LOAD=$(uptime | awk -F'load average:' '{print $2}')

        put "$ROW_RESP"  "${YELLOW}📊 Response:${NC} $PING_RESULT"
        put "$ROW_RATE"  "   ${YELLOW}⬇️  RX:${NC} ${WHITE}$(human_rate "$RX_RATE")${NC}   ${YELLOW}⬆️  TX:${NC} ${WHITE}$(human_rate "$TX_RATE")${NC}"
        put "$ROW_NET0"  "  ${NET[0]}"
        put "$ROW_NET1"  "  ${NET[1]}"
        put "$ROW_HPING" "   hping3: ${WHITE}$HPING_COUNT${NC}"
        put "$ROW_HTTP"  "   HTTP:   ${WHITE}$HTTP_COUNT${NC}"
        put "$ROW_CPU"   "${YELLOW}💻 CPU Usage:${NC} ${WHITE}${CPU:-0}%${NC}"
        put "$ROW_MEM"   "${YELLOW}🧠 Memory:${NC} ${WHITE}$MEM${NC} used"
        put "$ROW_LOAD"  "${YELLOW}📊 Load Average:${NC}${WHITE}$LOAD${NC}"
        put "$ROW_TIME"  "${WHITE}⏱️  Updated: $(date +%H:%M:%S)${NC}"
        sleep "$REFRESH"
    done
}

# ============================================================================
#  LOG MODE  (writes to file, no live screen)
# ============================================================================
monitor_log() {
    LOG_FILE="hexxFlood_monitor_$(date +%Y%m%d_%H%M%S).log"
    echo -e "${GREEN}📝 Logging to: $LOG_FILE${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    while true; do
        {
            echo "=== $(date) ==="
            echo "Target: $TARGET"
            ping -c 1 -W 1 "$TARGET" 2>/dev/null
            echo "Network Stats:"
            ifconfig "$INTERFACE" 2>/dev/null | grep -E "TX packets|RX packets"
            echo "Processes: $(pgrep -c hping3 2>/dev/null || echo 0)"
            echo ""
        } >> "$LOG_FILE"

        echo -e "${GREEN}✅ Logged at $(date +%H:%M:%S)${NC}"
        sleep "$REFRESH"
    done
}

# Cleanup
cleanup() {
    screen_done   # restore wrap + cursor hidden by the live monitors
    printf "\033[999;1H\n"
    echo -e "${YELLOW}🛑 Stopping monitor...${NC}"
    echo -e "${GREEN}✅ Monitor stopped${NC}"
    exit 0
}

# Main
main() {
    trap cleanup SIGINT SIGTERM
    trap screen_done EXIT   # never leave the terminal with wrap off / cursor hidden

    parse_args "$@"

    # Validate refresh interval (must be a positive number; sleep accepts decimals)
    if ! echo "$REFRESH" | grep -qE '^[0-9]+(\.[0-9]+)?$' || [ "$REFRESH" = "0" ]; then
        echo -e "${RED}Invalid refresh interval: $REFRESH (use a positive number, e.g. 1 or 0.5)${NC}"
        exit 1
    fi

    case $MONITOR_MODE in
        ping)    monitor_ping ;;
        network) monitor_network ;;
        system)  monitor_system ;;
        full)    monitor_full ;;
        log)     monitor_log ;;
        *)
            echo -e "${RED}Invalid mode: $MONITOR_MODE${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
