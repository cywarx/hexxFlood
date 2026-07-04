#!/bin/bash

# ============================================================
# hexxFlood - Universal Setup Script
# Version: 2.0
# ============================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Error handling
set -e
trap 'echo -e "${RED}❌ Error on line $LINENO${NC}"; exit 1' ERR

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (sudo ./setup.sh)${NC}"
    exit 1
fi

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
echo "║                          Universal Setup Script v2.0                           ║"
echo "║                                Use Responsibly!                                ║"
echo "╠════════════════════════════════════════════════════════════════════════════════╣"
echo "║                             Author: CyWarX                                     ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

SOURCE_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Run in place from the current folder by default (keeps it a git checkout so
# `hexxFlood -U` works natively). Override with HEXXFLOOD_INSTALL_DIR=/opt/... .
INSTALL_DIR="${HEXXFLOOD_INSTALL_DIR:-$SOURCE_DIR}"
echo -e "${GREEN}✅${NC} Source directory:  $SOURCE_DIR"
echo -e "${GREEN}✅${NC} Install directory: $INSTALL_DIR"

# Deploy (copy) the latest runtime files into the install directory so the
# installed tool always matches the current source checkout.
if [ "$SOURCE_DIR" -ef "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠️${NC} Running from the install directory — copy step skipped"
else
    mkdir -p "$INSTALL_DIR"
    for f in hexxFlood.sh monitor.sh quick.sh README.md LICENSE; do
        if [ -f "$SOURCE_DIR/$f" ]; then
            cp -f "$SOURCE_DIR/$f" "$INSTALL_DIR/$f"
            echo -e "${GREEN}✅${NC} Copied $f"
        fi
    done
    # hexxFlood.sh is now a thin entrypoint that sources lib/*.sh — the whole
    # lib/ directory must be deployed alongside it or the tool won't start.
    if [ -d "$SOURCE_DIR/lib" ]; then
        mkdir -p "$INSTALL_DIR/lib"
        cp -f "$SOURCE_DIR"/lib/*.sh "$INSTALL_DIR/lib/"
        echo -e "${GREEN}✅${NC} Copied lib/ ($(ls -1 "$SOURCE_DIR"/lib/*.sh | wc -l | tr -d ' ') modules)"
    fi
fi

# Everything below installs/points at the deployed copy
SCRIPT_DIR="$INSTALL_DIR"

# Resolve the real (non-root) user even when run via sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_HOME="${REAL_HOME:-$HOME}"
USER_SHELL=$(getent passwd "$REAL_USER" | cut -d: -f7)
SHELL_TYPE=$(basename "${USER_SHELL:-$SHELL}")
echo -e "${GREEN}✅${NC} Configuring for user: $REAL_USER ($REAL_HOME)"
echo -e "${GREEN}✅${NC} Detected shell: $SHELL_TYPE"

# Record the git source checkout so `hexxFlood -U` can self-update even when the
# install dir is a plain copy (e.g. HEXXFLOOD_INSTALL_DIR=/opt/hexxFlood). When
# install==source this marker is unused but harmless. Check ownership as the
# real user so git doesn't reject a user-owned checkout.
if sudo -u "$REAL_USER" git -C "$SOURCE_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    echo "$SOURCE_DIR" > "$INSTALL_DIR/.source_dir"
    chown "$REAL_USER": "$INSTALL_DIR/.source_dir" 2>/dev/null || true
    echo -e "${GREEN}✅${NC} Recorded update source: $SOURCE_DIR"
else
    rm -f "$INSTALL_DIR/.source_dir" 2>/dev/null
    echo -e "${YELLOW}⚠️${NC} Source is not a git checkout — 'hexxFlood -U' will be unavailable"
fi

echo -e "${GREEN}✅${NC} Updating package list..."
apt update -y 2>/dev/null || echo -e "${YELLOW}⚠️${NC} Update failed, continuing..."

echo -e "${GREEN}✅${NC} Installing dependencies..."
apt install -y hping3 net-tools sysstat ethtool bc dnsutils 2>/dev/null || {
    echo -e "${YELLOW}⚠️${NC} Some packages may already be installed"
}

if apt-cache show cpufrequtils &>/dev/null; then
    apt install -y cpufrequtils 2>/dev/null && echo -e "${GREEN}✅${NC} cpufrequtils installed"
else
    echo -e "${YELLOW}⚠️${NC} cpufrequtils not available - skipping"
fi

echo -e "${GREEN}✅${NC} Installing Python packages..."
# System packages (best-effort). The venv below is what hexxFlood actually
# runs its Python floods with, so the real dependency install happens there.
apt install -y python3-scapy python3-colorama python3-requests python3-pip 2>/dev/null || {
    echo -e "${YELLOW}⚠️${NC} Some Python packages may already be installed"
}

echo -e "${GREEN}✅${NC} Setting up Python virtual environment..."
# --system-site-packages lets the venv fall back to apt-installed modules if a
# pip install is blocked (offline / PEP-668), so the floods still find their libs.
if [ ! -d "/opt/hexxFlood-venv" ]; then
    python3 -m venv --system-site-packages /opt/hexxFlood-venv 2>/dev/null \
        || python3 -m venv /opt/hexxFlood-venv 2>/dev/null || {
        echo -e "${YELLOW}⚠️${NC} Virtual environment creation failed - using system Python"
    }
fi

# hexxFlood's Python floods import these:
#   requests          -> GraphQL flood       (lib/attacks.sh: graphql_flood.py)
#   h2                -> HTTP/2 flood         (lib/attacks.sh: http2_flood.py)
#   websocket-client  -> WebSocket flood      (lib/attacks.sh: websocket_flood.py)
#   scapy / colorama  -> packet crafting / colour
# The venv is the interpreter the tool prefers, so ALL of them must live here or
# --http2 / --websocket / --graphql print "requires X library" and do nothing.
HEXX_PYDEPS="scapy colorama requests h2 websocket-client"
if [ -d "/opt/hexxFlood-venv" ]; then
    source /opt/hexxFlood-venv/bin/activate 2>/dev/null
    pip install --upgrade pip 2>/dev/null
    if pip install $HEXX_PYDEPS 2>/dev/null; then
        echo -e "${GREEN}✅${NC} Installed Python deps into venv: $HEXX_PYDEPS"
    else
        echo -e "${YELLOW}⚠️${NC} pip install partial — floods fall back to system Python if needed"
    fi
    deactivate 2>/dev/null
    echo -e "${GREEN}✅${NC} Virtual environment configured at /opt/hexxFlood-venv"
else
    # No venv — make sure the deps at least exist for the system interpreter.
    pip3 install --break-system-packages $HEXX_PYDEPS 2>/dev/null \
        || pip3 install $HEXX_PYDEPS 2>/dev/null || true
fi

chmod +x "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/lib/*.sh 2>/dev/null
echo -e "${GREEN}✅${NC} Made hexxFlood.sh / monitor.sh / quick.sh + lib/ executable"

sudo rm -f /usr/local/bin/hexxFlood
sudo rm -f /usr/bin/hexxFlood
sudo rm -f /etc/sudoers.d/hexxFlood

echo -e "${GREEN}✅${NC} Creating wrapper script..."
sudo bash -c "cat > /usr/local/bin/hexxFlood << 'EOFWRAP'
#!/bin/bash
exec sudo bash \"$SCRIPT_DIR/hexxFlood.sh\" \"\$@\"
EOFWRAP"

sudo chmod +x /usr/local/bin/hexxFlood
echo -e "${GREEN}✅${NC} Wrapper created at /usr/local/bin/hexxFlood"

echo "$REAL_USER ALL=(ALL) NOPASSWD: /usr/local/bin/hexxFlood" | sudo tee /etc/sudoers.d/hexxFlood
sudo chmod 440 /etc/sudoers.d/hexxFlood
echo -e "${GREEN}✅${NC} Passwordless sudo configured"

if [ "$SHELL_TYPE" = "zsh" ]; then
    RC_FILE="$REAL_HOME/.zshrc"
elif [ "$SHELL_TYPE" = "bash" ]; then
    RC_FILE="$REAL_HOME/.bashrc"
else
    RC_FILE="$REAL_HOME/.profile"
fi

echo -e "${GREEN}✅${NC} Configuring $SHELL_TYPE environment..."

# Remove any previously-installed hexxFlood block. The current format is fenced
# by markers and deleted as a single unit, so nothing is ever left half-removed.
#
# NOTE: earlier versions used `sed -i '/hexxFlood/d'`, which deleted only the
# lines *containing* the word hexxFlood — leaving the completion function's body
# (`local -a commands` … `}`) orphaned at the top level of the rc file and
# breaking the shell on next login. The extra bounded deletes below clean up
# that legacy breakage without ever running greedily to EOF (which could eat a
# user's trailing config if an endpoint line is missing).
sed -i '/# >>> hexxFlood >>>/,/# <<< hexxFlood <<</d' "$RC_FILE" 2>/dev/null   # new fenced block
sed -i '/^_hexxFlood_completion()/,/^}/d' "$RC_FILE" 2>/dev/null               # legacy full function
sed -i '/^[[:space:]]*local -a commands$/,/^}/d' "$RC_FILE" 2>/dev/null        # legacy orphaned body
sed -i '/# hexxFlood Environment/d;/alias hexxFlood=/d;/compdef _hexxFlood_completion/d' "$RC_FILE" 2>/dev/null

# Base block: PATH + alias (safe for every shell).
{
    echo ""
    echo "# >>> hexxFlood >>>"
    echo "# hexxFlood Environment (managed block — regenerated by setup.sh; do not edit)"
    echo 'export PATH=$PATH:/usr/local/bin'
    echo 'alias hexxFlood="/usr/local/bin/hexxFlood"'
} >> "$RC_FILE"

# Tab-completion is zsh-specific (compadd/compdef) — only add it for zsh so it
# never lands in a .bashrc/.profile where it would throw errors.
if [ "$SHELL_TYPE" = "zsh" ]; then
    cat >> "$RC_FILE" << 'EOF2'

_hexxFlood_completion() {
    local -a commands
    commands=(
        '-t:Target IP (Layer 3/4 flood via hping3)'
        '-u:Target URL (auto-resolves + HTTP flood)'
        '--port:Target port'
        '-p:HTTP worker threads (default 50; mode overrides)'
        '-s:Packet size in bytes (64-65495)'
        '-d:Inter-packet delay hint (u1/u10/u100)'
        '-i:Network interface (default wlan0)'
        '-m:Mode (low,medium,high,extreme,apocalypse,god,custom)'
        '-P:Ports (comma-separated, floods each)'
        '-T:Type (syn,udp,icmp,ack,rst,fin,http,http2,websocket,graphql,ssl_reneg,slowloris,all)'
        '-D:Duration seconds (0=forever; extreme/apocalypse/god default 60s)'
        '--http2:Enable HTTP/2 flood'
        '--websocket:Enable WebSocket flood'
        '--graphql:Enable GraphQL flood'
        '--no-spoof:Use real source IP (no --rand-source)'
        '--fixed-ports:Hammer one static dst port'
        '--tune:Force safe system tuning on (restored on exit)'
        '--no-tune:Never touch system settings'
        '--tx-queue:NIC tx queue length while flooding'
        '--cap:Worker-count ceiling (any interface)'
        '--no-cap:Remove all worker caps (full power)'
        '--unlimited:Alias for --no-cap'
        '--monitor:Open live monitor only (no attack)'
        '--monitor-mode:Monitor mode (ping,network,system,full,log)'
        '--auto-monitor:Auto-open monitor window(s) on attack start'
        '--no-monitor:Do not auto-open a monitor window'
        '-U:Self-update (git pull)'
        '-V:Version'
        '-h:Help'
    )
    compadd -a commands
}
compdef _hexxFlood_completion hexxFlood 2>/dev/null || true
EOF2
fi

echo "# <<< hexxFlood <<<" >> "$RC_FILE"

echo -e "${GREEN}✅${NC} Added hexxFlood configuration to $RC_FILE"

export PATH=$PATH:/usr/local/bin

cat > "$REAL_HOME/.hexxFlood_config" << 'EOF3'
TARGET="192.168.1.14"
THREADS=50
PACKET_SIZE=65495
DELAY="u1"
INTERFACE="wlan0"
ATTACK_DURATION=0
SPOOF_IP=true
RANDOM_PORTS=true
AUTO_MONITOR=true
MONITOR_WINDOWS="full"
EOF3

# Ensure the real user owns the files we just wrote as root
chown "$REAL_USER": "$REAL_HOME/.hexxFlood_config" 2>/dev/null || true
chown "$REAL_USER": "$RC_FILE" 2>/dev/null || true

echo -e "${GREEN}✅${NC} Configuration saved to $REAL_HOME/.hexxFlood_config"

echo -e "${GREEN}✅${NC} Verifying installation..."

if command -v hping3 &>/dev/null; then
    echo -e "${GREEN}✅${NC} hping3: installed"
else
    echo -e "${RED}❌${NC} hping3: NOT FOUND"
fi

if command -v hexxFlood &>/dev/null; then
    echo -e "${GREEN}✅${NC} hexxFlood: available"
else
    echo -e "${RED}❌${NC} hexxFlood: NOT FOUND in PATH"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📖 Usage Examples:${NC}"
echo "  # IP Attack"
echo "  hexxFlood -t 192.168.1.10 -m extreme"
echo "  hexxFlood -t 192.168.1.10 -m apocalypse -D 60   # maximum overdrive"
echo ""
echo "  # Web URL Attack"
echo "  hexxFlood -u http://example.com -m extreme"
echo "  hexxFlood -u https://example.com -T http -p 100"
echo "  hexxFlood -u http://example.com:8080 -m high -D 60"
echo ""
echo -e "${CYAN}⚙️  Notes:${NC}"
echo "  • On Wi-Fi the worker count auto-caps to the real throughput peak (~4× cores)."
echo "  • high/extreme/apocalypse/god apply safe system tuning that is restored on exit."
echo "  • extreme/apocalypse/god auto-stop after 60s unless you pass -D."
echo ""
echo -e "${CYAN}📁 Installation Details:${NC}"
echo "  Source Dir:  $SOURCE_DIR"
echo "  Install Dir: $INSTALL_DIR"
echo "  Wrapper:     /usr/local/bin/hexxFlood"
echo "  Config:      ~/.hexxFlood_config"
echo "  Shell RC:    $RC_FILE"
echo ""
echo -e "${YELLOW}💡 To use without restarting:${NC}"
echo "  source $RC_FILE"
echo ""
echo -e "${RED}⚠️  WARNING: Use only on networks you OWN or have permission to test!${NC}"
echo ""

read -p "Reload shell configuration now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    source "$RC_FILE" 2>/dev/null || {
        echo -e "${YELLOW}⚠️${NC} Could not reload automatically. Please restart your terminal."
    }
    echo -e "${GREEN}✅${NC} Shell configuration reloaded!"
fi

echo ""
echo -e "${GREEN}✅ hexxFlood is ready! 🚀${NC}"
