#!/usr/bin/env bash
# ============================================================
# hexxFlood :: lib/config.sh
# Colors, version, and ALL default configuration / state.
# This module is SOURCED by hexxFlood.sh — it defines no logic,
# only variables. Sourced first so every other module sees them.
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
DIM='\033[2m'
BLINK='\033[5m'
NC='\033[0m'

# Version
VERSION="4.0-GOD-MODE-FULL"
REPO_URL="https://github.com/Cywarx/hexxFlood.git"

# ============================================================
# CORE CONFIGURATION
# ============================================================
CONFIG_FILE="$HOME/.hexxFlood_config"
TARGET="192.168.1.14"
TARGET_PORT=80
THREADS=50
PACKET_SIZE=65495
DELAY="u1"
INTERFACE="wlan0"
ATTACK_DURATION=0
SPOOF_IP=true
RANDOM_PORTS=true
TARGET_TYPE="ip"
BOT_MODE=false
BOT_MASTER=""
BOT_TOKEN=""
BOT_ID=$(uuidgen 2>/dev/null || echo "bot-$(date +%s)-$RANDOM")

# ============================================================
# PROTOCOL FEATURES
# ============================================================
ENABLE_HTTP2=false
ENABLE_HTTP3=false
ENABLE_WEBSOCKETS=false
ENABLE_SSE=false
ENABLE_GRAPHQL=false
ENABLE_GRPC=false
ENABLE_WEBRTC=false

# ============================================================
# REQUEST GENERATION
# ============================================================
MIN_PAYLOAD_SIZE=0
MAX_PAYLOAD_SIZE=65536
VARIABLE_PAYLOAD=true
RANDOMIZE_HEADERS=false
RANDOMIZE_COOKIES=false
ENABLE_SESSION_TRACKING=false
ENABLE_AUTH_BYPASS=false
CUSTOM_PAYLOAD=""
PAYLOAD_FILE=""
PAYLOAD_SIZE=1024

# ============================================================
# RATE LIMITING (NEW)
# ============================================================
ENABLE_RATE_LIMIT=false
RATE_LIMIT_PPS=0
RATE_LIMIT_BPS=0
THROTTLE_DELAY=0

# ============================================================
# TRAFFIC DISTRIBUTION
# ============================================================
ENABLE_MULTI_SERVER=false
SERVER_LIST=()
ENABLE_IP_ROTATION=false
IP_ROTATION_INTERVAL=60
IP_POOL=()
ENABLE_GEOLOCATION=false
GEOLOCATION_TARGETS=()
ENABLE_CDN_TARGETING=false
CDN_EDGE_NODES=()

# ============================================================
# PERFORMANCE OPTIMIZATION
# ============================================================
ENABLE_CONNECTION_POOLING=false
CONNECTION_POOL_SIZE=1000
ENABLE_ASYNC_IO=false
ASYNC_WORKERS=100
ENABLE_ZERO_COPY=false
ENABLE_PARALLEL_CONNECTIONS=false
PARALLEL_CONNECTIONS=500

# ============================================================
# STEALTH TECHNIQUES
# ============================================================
ENABLE_TIMING_RANDOMIZATION=false
TIMING_JITTER=50
ENABLE_FINGERPRINT_SPOOFING=false
FINGERPRINT_ROTATION_INTERVAL=300
ENABLE_USERAGENT_ROTATION=false
USERAGENT_ROTATION_INTERVAL=60
ENABLE_REFERER_SPOOFING=false
REFERER_LIST=(
    "https://www.google.com/"
    "https://www.bing.com/"
    "https://duckduckgo.com/"
)

# ============================================================
# ATTACK SCALING
# ============================================================
ENABLE_DYNAMIC_RATE=false
BASE_RATE=1000
MAX_RATE=1000000
ENABLE_BURST_CONTROL=false
BURST_SIZE=5000
BURST_INTERVAL=10
ENABLE_PRIORITY_QUEUE=false
ENABLE_ADAPTIVE_THROTTLING=false
THROTTLE_THRESHOLD=80

# ============================================================
# RESOURCE MANAGEMENT
# ============================================================
ENABLE_MEMORY_EFFICIENT=true
MEMORY_POOL_SIZE=4096
ENABLE_NUMA_AWARE=false
NUMA_NODES=()
ENABLE_CONNECTION_RECYCLING=false
CONNECTION_TTL=300
ENABLE_BANDWIDTH_OPTIMIZATION=false
TARGET_BANDWIDTH=1000000000

# ============================================================
# ANALYTICS
# ============================================================
ENABLE_REALTIME_METRICS=false
METRICS_INTERVAL=1
ENABLE_ERROR_CORRELATION=false
ENABLE_ANOMALY_DETECTION=false
ANOMALY_THRESHOLD=3
ENABLE_PATTERN_RECOGNITION=false
ENABLE_LOGGING=true
LOG_FILE="/tmp/hexxflood_attack.log"
ENABLE_REPORTING=true
REPORT_FILE="/tmp/hexxflood_report.txt"

# ============================================================
# RESILIENCE
# ============================================================
ENABLE_AUTO_RECOVERY=false
MAX_RETRY_ATTEMPTS=5
ENABLE_LOAD_BALANCING=false
LOAD_BALANCE_ALGORITHM="round_robin"
ENABLE_SELF_HEALING=false
HEAL_CHECK_INTERVAL=10
ENABLE_FAILOVER=false
BACKUP_TARGETS=()

# ============================================================
# INTEGRATION
# ============================================================
ENABLE_API=false
API_PORT=8080
ENABLE_PLUGINS=false
PLUGIN_DIR="$HOME/.hexxflood/plugins"
ENABLE_CLOUD_INTEGRATION=false
CLOUD_PROVIDERS=()
ENABLE_SIEM_INTEGRATION=false
SIEM_ENDPOINT=""
SIEM_API_KEY=""

# ============================================================
# PERFORMANCE TUNING
# ============================================================
EXTREME_PACKET_BURST=1000
EXTREME_MTU=9000
EXTREME_TX_QUEUE=10000
EXTREME_CPU_PRIORITY=-20
EXTREME_NICE_LEVEL=-20
EXTREME_CORE_PINNING=false
EXTREME_USE_HUGEPAGES=false
EXTREME_MULTI_IFACE=false

# ============================================================
# STATE VARIABLES
# ============================================================
declare -A SAVED_SYSCTL
RUN_AS_ROOT=0
AUTO_ROOT="${AUTO_ROOT:-}"
FLOOD_WORKERS=0
CORES=0
WORKERS_FORCED=0
WIFI_CAPPED=0
CAP_REASON=""
TUNING_APPLIED=0
ATTACK_START_TIME=0
ATTACK_INITIAL_PACKETS=0
HPING_SAMPLER_PID=0
HPING_LOG=""
ALT_SCREEN=0
CLEANUP_DONE=0
DASHBOARD_ACTIVE=0
SCRIPT_ARGS=()
INTERFACES=()
CPU_PREV_TOTAL=0
CPU_PREV_IDLE=0
LOAD_BALANCE_INDEX=0
SIZE_SET=0
DURATION_SET=0
SYS_TUNE=false
TX_QUEUE_LEN=10000
NO_CAP=false
AUTO_MONITOR=false
MONITOR_MODE="full"
MONITOR_WINDOWS="full"
URL=""
WEB_HOST=""
WEB_PORT=""
WEB_IP=""
CUSTOM_PORTS=""
ATTACK_TYPES="all"
MODE=""
WORKER_CAP=""
MON_DISPLAY=""
MON_HOME=""
RUN_MONITOR_ONLY=false

# Statistics
TOTAL_PACKETS_SENT=0
TOTAL_BYTES_SENT=0
PEAK_PPS=0
AVG_PPS=0
TOTAL_REQUESTS=0
SUCCESSFUL_REQUESTS=0
FAILED_REQUESTS=0
AVG_RESPONSE_TIME=0
ACTIVE_CONNECTIONS=0
BOT_COUNT=0

# Arrays
HIGH_PRIORITY=()
MEDIUM_PRIORITY=()
LOW_PRIORITY=()
declare -A BOT_NODES
declare -A BOT_STATUS
declare -A LOADED_PLUGINS
BOT_COMMANDS=()
