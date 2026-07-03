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

# Default values
TARGET="192.168.1.14"
INTERFACE="wlan0"
MONITOR_MODE="full"

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
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
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
    echo -e "${GREEN}📊 Monitoring target: $TARGET${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}📍 TARGET: $TARGET${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        PING_RESULT=$(ping -c 3 $TARGET 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "$PING_RESULT" | grep -E "time=|bytes from" | tail -3
            echo ""
            echo "$PING_RESULT" | grep -E "packets transmitted|rtt"
        else
            echo -e "${RED}💀 TARGET UNRESPONSIVE!${NC}"
        fi
        
        echo ""
        echo -e "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)${NC}"
        sleep 2
    done
}

# Monitor Network
monitor_network() {
    echo -e "${GREEN}📡 Monitoring network: $INTERFACE${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}📡 NETWORK STATS ($INTERFACE)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        ifconfig $INTERFACE 2>/dev/null | grep -E "TX packets|RX packets|TX bytes|RX bytes"
        echo ""
        
        # Active connections
        CONNECTIONS=$(netstat -an 2>/dev/null | grep -c ESTABLISHED)
        echo -e "${YELLOW}Active Connections:${NC} $CONNECTIONS"
        
        # hping3 processes
        HPING_COUNT=$(ps aux | grep -c hping3)
        echo -e "${YELLOW}hping3 Processes:${NC} $HPING_COUNT"
        
        echo ""
        echo -e "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)${NC}"
        sleep 2
    done
}

# Monitor System
monitor_system() {
    echo -e "${GREEN}💻 Monitoring system resources${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}💻 SYSTEM RESOURCES${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # CPU
        CPU=$(top -bn1 | head -3 | grep Cpu | awk '{print $2}')
        echo -e "${YELLOW}CPU Usage:${NC} ${CPU:-0}%"
        
        # Memory
        MEM=$(free -h | grep Mem | awk '{print $3 "/" $2}')
        echo -e "${YELLOW}Memory:${NC} $MEM"
        
        # Load
        LOAD=$(uptime | awk -F'load average:' '{print $2}')
        echo -e "${YELLOW}Load Average:${NC}$LOAD"
        
        # Processes
        HPING_COUNT=$(ps aux | grep -c hping3)
        HTTP_COUNT=$(ps aux | grep -c http_flood.py)
        echo ""
        echo -e "${YELLOW}Attack Processes:${NC}"
        echo "  hping3: $HPING_COUNT"
        echo "  HTTP:   $HTTP_COUNT"
        
        # Top processes
        echo ""
        echo -e "${YELLOW}Top CPU Processes:${NC}"
        ps aux --sort=-%cpu | head -6 | tail -5 | awk '{print "  " $11 " - " $3 "%"}'
        
        echo ""
        echo -e "${YELLOW}⏱️  Updated: $(date +%H:%M:%S)${NC}"
        sleep 2
    done
}

# Monitor Full
monitor_full() {
    echo -e "${GREEN}📊 FULL MONITORING MODE${NC}"
    echo -e "${YELLOW}Target: $TARGET | Interface: $INTERFACE${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        clear
        show_banner
        
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                    ☢️  hexxFlood MONITOR  ☢️${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Target Status
        echo -e "${YELLOW}📍 TARGET:${NC} $TARGET"
        PING_RESULT=$(ping -c 1 $TARGET 2>/dev/null | grep -o "time=[0-9.]* ms" || echo "💀 TARGET UNRESPONSIVE!")
        echo -e "${YELLOW}📊 Response:${NC} $PING_RESULT"
        echo ""
        
        # Network Stats
        echo -e "${YELLOW}📡 NETWORK ($INTERFACE):${NC}"
        ifconfig $INTERFACE 2>/dev/null | grep -E "TX packets|RX packets"
        echo ""
        
        # Process Count
        HPING_COUNT=$(ps aux | grep -c hping3)
        HTTP_COUNT=$(ps aux | grep -c http_flood.py)
        echo -e "${YELLOW}🔢 Active Processes:${NC}"
        echo "   hping3: $HPING_COUNT"
        echo "   HTTP:   $HTTP_COUNT"
        echo ""
        
        # CPU
        CPU=$(top -bn1 | head -5 | grep Cpu | awk '{print $2}')
        echo -e "${YELLOW}💻 CPU Usage:${NC} ${CPU:-0}%"
        echo ""
        
        # Memory
        MEM=$(free -h | grep Mem | awk '{print $3 "/" $2}')
        echo -e "${YELLOW}🧠 Memory:${NC} $MEM used"
        echo ""
        
        # System Load
        LOAD=$(uptime | awk -F'load average:' '{print $2}')
        echo -e "${YELLOW}📊 Load Average:${NC}$LOAD"
        echo ""
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}⏱️  Updated: $(date +%H:%M:%S)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}Press Ctrl+C to stop monitoring${NC}"
        
        sleep 2
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
    echo -e "\n${YELLOW}🛑 Stopping monitor...${NC}"
    echo -e "${GREEN}✅ Monitor stopped${NC}"
    exit 0
}

# Main
main() {
    trap cleanup SIGINT SIGTERM
    
    parse_args "$@"
    
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
