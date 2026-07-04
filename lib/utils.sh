#!/usr/bin/env bash
# ============================================================
# hexxFlood :: lib/utils.sh
# Core helpers: interface counters, CPU/mem sampling, bar
# drawing, byte/pps formatting, logging, URL parsing, and the
# git self-update machinery. Pure helpers — no attack logic.
# ============================================================

get_packet_count() {
    local iface="${1:-$INTERFACE}" c
    c=$(cat "/sys/class/net/$iface/statistics/tx_packets" 2>/dev/null)
    if [ -z "$c" ] || [ "$c" = "" ]; then
        c=$(ifconfig "$iface" 2>/dev/null | grep "TX packets" | awk '{print $5}' | head -1)
    fi
    echo "${c:-0}"
}

get_tx_bytes() {
    local iface="${1:-$INTERFACE}" c
    c=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null)
    if [ -z "$c" ] || [ "$c" = "" ]; then
        c=$(ifconfig "$iface" 2>/dev/null | grep "TX bytes" | awk '{print $3}' | head -1)
    fi
    echo "${c:-0}"
}

cpu_busy_pct() {
    local a b c d e f g rest idle total dt di
    read -r _ a b c d e f g rest < /proc/stat 2>/dev/null
    idle=$(( d + e ))
    total=$(( a + b + c + d + e + f + g ))
    dt=$(( total - ${CPU_PREV_TOTAL:-0} ))
    di=$(( idle - ${CPU_PREV_IDLE:-0} ))
    CPU_PREV_TOTAL=$total
    CPU_PREV_IDLE=$idle
    if [ "$dt" -le 0 ]; then echo 0; else echo $(( (100 * (dt - di)) / dt )); fi
}

mem_used_str() {
    awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2}
         END{printf "%.1f/%.1fG", (t-a)/1048576, t/1048576}' /proc/meminfo 2>/dev/null
}

draw_bar() {
    local v=$1 max=$2 w=$3 filled i out=""
    [ "$max" -le 0 ] && max=1
    filled=$(( v * w / max )); [ $filled -gt $w ] && filled=$w; [ $filled -lt 0 ] && filled=0
    for ((i = 0; i < filled; i++)); do out+="█"; done
    for ((i = filled; i < w; i++)); do out+="░"; done
    printf '%s' "$out"
}

pln() { printf '%b\033[K\r\n' "$1"; }

fmt_bps() {
    awk -v b="$1" 'BEGIN{
        if (b>=1e9)      printf "%.2f Gbps", b/1e9;
        else if (b>=1e6) printf "%.1f Mbps", b/1e6;
        else if (b>=1e3) printf "%.1f Kbps", b/1e3;
        else             printf "%d bps", b;
    }'
}

log_attack() {
    local message="$1"
    local level="${2:-INFO}"
    
    if [ "$ENABLE_LOGGING" = true ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE" 2>/dev/null
    fi
}

# ---- URL parsing -------------------------------------------

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
    if [[ "$WEB_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        WEB_IP="$WEB_HOST"
    else
        WEB_IP=$(dig +short "$WEB_HOST" 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
        if [ -z "$WEB_IP" ]; then
            WEB_IP=$(ping -c 1 -W 2 "$WEB_HOST" 2>/dev/null | head -1 | grep -oP '\(\K[0-9.]+' 2>/dev/null)
        fi
    fi
    if [ -z "$WEB_IP" ]; then
        echo -e "${RED}❌ Could not resolve hostname: $WEB_HOST${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Resolved $WEB_HOST -> $WEB_IP${NC}"
    TARGET="$WEB_IP"
    TARGET_TYPE="url"
    URL="$url"
    TARGET_PORT="${WEB_PORT:-80}"
    return 0
}

# ---- self-update -------------------------------------------

git_is_repo() {
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" git -C "$1" rev-parse --is-inside-work-tree &>/dev/null
    else
        git -C "$1" rev-parse --is-inside-work-tree &>/dev/null
    fi
}

deploy_runtime() {
    local src="$1" dst="$2" f
    [ "$src" -ef "$dst" ] && return 0
    for f in hexxFlood.sh monitor.sh quick.sh setup.sh README.md LICENSE; do
        [ -f "$src/$f" ] && cp -f "$src/$f" "$dst/$f" 2>/dev/null
    done
    # The engine (lib/) and the Layer-7 payloads (payloads/) MUST travel with
    # hexxFlood.sh or the deployed copy can't source its modules / run L7 floods.
    if [ -d "$src/lib" ]; then
        mkdir -p "$dst/lib" 2>/dev/null
        cp -f "$src"/lib/*.sh "$dst/lib/" 2>/dev/null
    fi
    if [ -d "$src/payloads" ]; then
        mkdir -p "$dst/payloads" 2>/dev/null
        cp -f "$src"/payloads/*.py "$dst/payloads/" 2>/dev/null
    fi
    chmod +x "$dst"/*.sh "$dst"/lib/*.sh "$dst"/payloads/*.py 2>/dev/null
    echo -e "${GREEN}✅ Redeployed updated files to $dst${NC}"
}

self_update() {
    # Use the entrypoint's resolved location (hexxFlood.sh's dir), NOT this
    # module's — self_update lives in lib/ but must act on the repo/install root.
    local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"

    echo -e "${CYAN}🔄 Checking for updates...${NC}"

    if ! command -v git &>/dev/null; then
        echo -e "${RED}❌ git is not installed.${NC}"
        exit 1
    fi

    local repo_dir="$script_dir"
    local deploy=false
    if ! git_is_repo "$repo_dir"; then
        local src=""
        [ -f "$script_dir/.source_dir" ] && src="$(cat "$script_dir/.source_dir" 2>/dev/null)"
        if [ -n "$src" ] && git_is_repo "$src"; then
            repo_dir="$src"
            deploy=true
        else
            echo -e "${RED}❌ Not a git repository.${NC}"
            exit 1
        fi
    fi

    local git_cmd=(git -C "$repo_dir")
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        git_cmd=(sudo -u "$SUDO_USER" git -C "$repo_dir")
    fi

    local branch
    branch="$("${git_cmd[@]}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ -z "$branch" ] || [ "$branch" = "HEAD" ] && branch="main"

    if ! "${git_cmd[@]}" fetch --quiet origin "$branch" 2>/dev/null; then
        echo -e "${RED}❌ Could not reach remote.${NC}"
        exit 1
    fi

    local local_rev remote_rev
    local_rev="$("${git_cmd[@]}" rev-parse HEAD)"
    remote_rev="$("${git_cmd[@]}" rev-parse "origin/$branch" 2>/dev/null)"

    if [ "$local_rev" = "$remote_rev" ]; then
        echo -e "${GREEN}✅ Already up to date.${NC}"
        [ "$deploy" = true ] && deploy_runtime "$repo_dir" "$script_dir"
        exit 0
    fi

    echo -e "${YELLOW}⬆️  Update available...${NC}"
    if "${git_cmd[@]}" pull --ff-only origin "$branch"; then
        chmod +x "$repo_dir"/*.sh 2>/dev/null
        [ "$deploy" = true ] && deploy_runtime "$repo_dir" "$script_dir"
        echo -e "${GREEN}✅ Updated!${NC}"
    else
        echo -e "${RED}❌ Update failed.${NC}"
        exit 1
    fi
    exit 0
}
