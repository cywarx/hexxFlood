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

# In-place rendering helpers (flicker-free updates)
EL='\033[K'          # erase from cursor to end of line
HOME='\033[H'        # move cursor to top-left
CLR_BELOW='\033[J'   # erase from cursor to end of screen

hide_cursor() { tput civis 2>/dev/null; }
show_cursor() { tput cnorm 2>/dev/null; }

# Default values
TARGET="192.168.1.14"
INTERFACE="wlan0"
MONITOR_MODE="full"
REFRESH="1"          # seconds between updates (lower = more real-time)

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

# Show banner
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

# Banner for in-place rendering: no clear, each line erases its own leftovers
banner_frame() {
    echo -e "${CYAN}${EL}"
    echo -e "╔══════════════════════════════════════════════════════════════════╗${EL}"
    echo -e "║                                                                  ║${EL}"
    echo -e "║   ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗    ║${EL}"
    echo -e "║   ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗   ║${EL}"
    echo -e "║   ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝   ║${EL}"
    echo -e "║   ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗   ║${EL}"
    echo -e "║   ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║   ║${EL}"
    echo -e "║   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ║${EL}"
    echo -e "║                                                                  ║${EL}"
    echo -e "║              hexxFlood - Monitoring Script v1.0                  ║${EL}"
    echo -e "╠══════════════════════════════════════════════════════════════════╣${EL}"
    echo -e "║                       Author: CyWarX                             ║${EL}"
    echo -e "╚══════════════════════════════════════════════════════════════════╝${EL}"
    echo -e "${NC}${EL}"
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
            -t|--target)
                TARGET="$2"
                shift 2
                ;;
            -i|--interface)
                INTERFACE="$2"
                shift 2
                ;;
            -m|--mode)
                MONITOR_MODE="$2"
                shift 2
                ;;
            -r|--refresh)
                REFRESH="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# Monitor Ping
monitor_ping() {
    hide_cursor
    printf "${CLR_BELOW}"   # clear once; loop redraws in place from here on

    while true; do
        printf "${HOME}"    # cursor to top-left, no screen blank = no flicker

        echo -e "${GREEN}📊 Monitoring target: $TARGET${NC}${EL}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}${EL}"
        echo -e "${EL}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}${EL}"
        echo -e "${WHITE}📍 TARGET: $TARGET${NC}${EL}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}${EL}"

        # Single fast ping with a 1s timeout so a dead target never stalls the loop
        if PING_LINE=$(ping -c 1 -W 1 "$TARGET" 2>/dev/null | grep -E "bytes from"); then
            LAT=$(echo "$PING_LINE" | grep -o "time=[0-9.]* ms")
            echo -e "${GREEN}✅ ALIVE${NC}   ${YELLOW}Latency:${NC} ${LAT:-n/a}${EL}"
            echo -e "$PING_LINE${EL}"
        else
            echo -e "${RED}💀 TARGET UNRESPONSIVE!${NC}${EL}"
            echo -e "${EL}"
        fi

        echo -e "${EL}"
        echo -e "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)  (every ${REFRESH}s)${NC}${EL}"
        printf "${CLR_BELOW}"   # wipe any leftover lines from a previous larger frame
        sleep "$REFRESH"
    done
}

# Monitor Network
monitor_network() {
    hide_cursor
    printf "${CLR_BELOW}"

    # Prime the throughput counters so the first frame shows a real rate
    read_bytes "$INTERFACE"; RX_PREV=$RX_NOW; TX_PREV=$TX_NOW; TS_PREV=$(date +%s.%N)

    while true; do
        printf "${HOME}"

        # Live throughput: byte deltas divided by the ACTUAL elapsed time
        read_bytes "$INTERFACE"; TS_NOW=$(date +%s.%N)
        RX_RATE=$(awk "BEGIN{dt=$TS_NOW-$TS_PREV; if(dt<=0)dt=$REFRESH; r=($RX_NOW-$RX_PREV)/dt; if(r<0)r=0; printf \"%d\", r}")
        TX_RATE=$(awk "BEGIN{dt=$TS_NOW-$TS_PREV; if(dt<=0)dt=$REFRESH; r=($TX_NOW-$TX_PREV)/dt; if(r<0)r=0; printf \"%d\", r}")
        RX_PREV=$RX_NOW; TX_PREV=$TX_NOW; TS_PREV=$TS_NOW

        echo -e "${GREEN}📡 Monitoring network: $INTERFACE${NC}${EL}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}${EL}"
        echo -e "${EL}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}${EL}"
        echo -e "${WHITE}📡 NETWORK STATS ($INTERFACE)${NC}${EL}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}${EL}"

        # Real-time throughput (the numbers that change live)
        echo -e "${YELLOW}⬇️  RX Rate:${NC} $(human_rate "$RX_RATE")${EL}"
        echo -e "${YELLOW}⬆️  TX Rate:${NC} $(human_rate "$TX_RATE")${EL}"
        echo -e "${EL}"

        ifconfig "$INTERFACE" 2>/dev/null | grep -E "TX packets|RX packets|TX bytes|RX bytes" | while IFS= read -r line; do
            echo -e "${line}${EL}"
        done
        echo -e "${EL}"

        # Active connections
        CONNECTIONS=$(netstat -an 2>/dev/null | grep -c ESTABLISHED)
        echo -e "${YELLOW}Active Connections:${NC} $CONNECTIONS${EL}"

        # hping3 processes
        HPING_COUNT=$(pgrep -c hping3 2>/dev/null || echo 0)
        echo -e "${YELLOW}hping3 Processes:${NC} $HPING_COUNT${EL}"

        echo -e "${EL}"
        echo -e "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)  (every ${REFRESH}s)${NC}${EL}"
        printf "${CLR_BELOW}"
        sleep "$REFRESH"
    done
}

# Monitor System
monitor_system() {
    hide_cursor
    printf "${CLR_BELOW}"

    while true; do
        printf "${HOME}"

        echo -e "${GREEN}💻 Monitoring system resources${NC}${EL}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}${EL}"
        echo -e "${EL}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}${EL}"
        echo -e "${WHITE}💻 SYSTEM RESOURCES${NC}${EL}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}${EL}"

        # CPU
        CPU=$(top -bn1 | head -3 | grep Cpu | awk '{print $2}')
        echo -e "${YELLOW}CPU Usage:${NC} ${CPU:-0}%${EL}"

        # Memory
        MEM=$(free -h | grep Mem | awk '{print $3 "/" $2}')
        echo -e "${YELLOW}Memory:${NC} $MEM${EL}"

        # Load
        LOAD=$(uptime | awk -F'load average:' '{print $2}')
        echo -e "${YELLOW}Load Average:${NC}$LOAD${EL}"

        # Processes
        HPING_COUNT=$(pgrep -c hping3 2>/dev/null || echo 0)
        HTTP_COUNT=$(pgrep -fc http_flood.py 2>/dev/null || echo 0)
        echo -e "${EL}"
        echo -e "${YELLOW}Attack Processes:${NC}${EL}"
        echo -e "  hping3: $HPING_COUNT${EL}"
        echo -e "  HTTP:   $HTTP_COUNT${EL}"

        # Top processes
        echo -e "${EL}"
        echo -e "${YELLOW}Top CPU Processes:${NC}${EL}"
        ps aux --sort=-%cpu | head -6 | tail -5 | awk '{print "  " $11 " - " $3 "%"}' | while IFS= read -r line; do
            echo -e "${line}${EL}"
        done

        echo -e "${EL}"
        echo -e "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)  (every ${REFRESH}s)${NC}${EL}"
        printf "${CLR_BELOW}"
        sleep "$REFRESH"
    done
}

# Monitor Full
monitor_full() {
    hide_cursor
    printf "${CLR_BELOW}"   # clear the screen ONCE; the loop then repaints in place

    # Prime throughput counters for the live RX/TX rate
    read_bytes "$INTERFACE"; RX_PREV=$RX_NOW; TX_PREV=$TX_NOW; TS_PREV=$(date +%s.%N)

    while true; do
        # Move cursor home and overwrite the previous frame — no clear, so no flicker.
        # Each line ends with ${EL} to wipe its own leftovers; ${CLR_BELOW} at the
        # end removes any trailing lines from a previously larger frame.
        printf "${HOME}"
        banner_frame

        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}${EL}"
        echo -e "${WHITE}                    ☢️  hexxFlood MONITOR  ☢️${NC}${EL}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}${EL}"
        echo -e "${EL}"

        # Live throughput: byte deltas divided by the ACTUAL elapsed time
        read_bytes "$INTERFACE"; TS_NOW=$(date +%s.%N)
        RX_RATE=$(awk "BEGIN{dt=$TS_NOW-$TS_PREV; if(dt<=0)dt=$REFRESH; r=($RX_NOW-$RX_PREV)/dt; if(r<0)r=0; printf \"%d\", r}")
        TX_RATE=$(awk "BEGIN{dt=$TS_NOW-$TS_PREV; if(dt<=0)dt=$REFRESH; r=($TX_NOW-$TX_PREV)/dt; if(r<0)r=0; printf \"%d\", r}")
        RX_PREV=$RX_NOW; TX_PREV=$TX_NOW; TS_PREV=$TS_NOW

        # Target Status (1s timeout so a dead target never stalls the refresh)
        echo -e "${YELLOW}📍 TARGET:${NC} $TARGET${EL}"
        PING_RESULT=$(ping -c 1 -W 1 "$TARGET" 2>/dev/null | grep -o "time=[0-9.]* ms" | head -1)
        [ -z "$PING_RESULT" ] && PING_RESULT="💀 TARGET UNRESPONSIVE!"
        echo -e "${YELLOW}📊 Response:${NC} $PING_RESULT${EL}"
        echo -e "${EL}"

        # Network Stats + live throughput
        echo -e "${YELLOW}📡 NETWORK ($INTERFACE):${NC}${EL}"
        echo -e "   ${YELLOW}⬇️  RX Rate:${NC} $(human_rate "$RX_RATE")   ${YELLOW}⬆️  TX Rate:${NC} $(human_rate "$TX_RATE")${EL}"
        ifconfig "$INTERFACE" 2>/dev/null | grep -E "TX packets|RX packets" | while IFS= read -r line; do
            echo -e "${line}${EL}"
        done
        echo -e "${EL}"

        # Process Count
        HPING_COUNT=$(pgrep -c hping3 2>/dev/null || echo 0)
        HTTP_COUNT=$(pgrep -fc http_flood.py 2>/dev/null || echo 0)
        echo -e "${YELLOW}🔢 Active Processes:${NC}${EL}"
        echo -e "   hping3: $HPING_COUNT${EL}"
        echo -e "   HTTP:   $HTTP_COUNT${EL}"
        echo -e "${EL}"

        # CPU
        CPU=$(top -bn1 | head -5 | grep Cpu | awk '{print $2}')
        echo -e "${YELLOW}💻 CPU Usage:${NC} ${CPU:-0}%${EL}"
        echo -e "${EL}"

        # Memory
        MEM=$(free -h | grep Mem | awk '{print $3 "/" $2}')
        echo -e "${YELLOW}🧠 Memory:${NC} $MEM used${EL}"
        echo -e "${EL}"

        # System Load
        LOAD=$(uptime | awk -F'load average:' '{print $2}')
        echo -e "${YELLOW}📊 Load Average:${NC}$LOAD${EL}"
        echo -e "${EL}"

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}${EL}"
        echo -e "${WHITE}⏱️  Updated: $(date +%H:%M:%S)${NC}${EL}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}${EL}"
        echo -e "${RED}Press Ctrl+C to stop monitoring${NC}   (refresh: every ${REFRESH}s)${EL}"

        printf "${CLR_BELOW}"
        sleep "$REFRESH"
    done
}

# Monitor Log
monitor_log() {
    LOG_FILE="hexxFlood_monitor_$(date +%Y%m%d_%H%M%S).log"
    echo -e "${GREEN}📝 Logging to: $LOG_FILE${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        echo "=== $(date) ===" >> $LOG_FILE
        echo "Target: $TARGET" >> $LOG_FILE
        ping -c 1 $TARGET 2>/dev/null >> $LOG_FILE
        echo "Network Stats:" >> $LOG_FILE
        ifconfig $INTERFACE 2>/dev/null | grep -E "TX packets|RX packets" >> $LOG_FILE
        echo "Processes: $(ps aux | grep -c hping3)" >> $LOG_FILE
        echo "" >> $LOG_FILE
        
        echo -e "${GREEN}✅ Logged at $(date +%H:%M:%S)${NC}"
        sleep 5
    done
}

# Cleanup
cleanup() {
    show_cursor   # restore cursor hidden by the in-place monitors
    echo -e "\n${YELLOW}🛑 Stopping monitor...${NC}"
    echo -e "${GREEN}✅ Monitor stopped${NC}"
    exit 0
}

# Main
main() {
    trap cleanup SIGINT SIGTERM
    trap show_cursor EXIT   # never leave the terminal with a hidden cursor

    parse_args "$@"

    # Validate refresh interval (must be a positive number; sleep accepts decimals)
    if ! echo "$REFRESH" | grep -qE '^[0-9]+(\.[0-9]+)?$' || [ "$REFRESH" = "0" ]; then
        echo -e "${RED}Invalid refresh interval: $REFRESH (use a positive number, e.g. 1 or 0.5)${NC}"
        exit 1
    fi

    case $MONITOR_MODE in
        ping)
            monitor_ping
            ;;
        network)
            monitor_network
            ;;
        system)
            monitor_system
            ;;
        full)
            monitor_full
            ;;
        log)
            monitor_log
            ;;
        *)
            echo -e "${RED}Invalid mode: $MONITOR_MODE${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
