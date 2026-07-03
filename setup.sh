#!/bin/bash

# ============================================================
# hexxFlood - Universal Setup Script
# Version: 1.0
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
echo "║                          Universal Setup Script v1.0                           ║"
echo "║                                Use Responsibly!                                ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

SCRIPT_DIR="$(pwd)"
echo -e "${GREEN}✅${NC} Installation directory: $SCRIPT_DIR"

# Resolve the real (non-root) user even when run via sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_HOME="${REAL_HOME:-$HOME}"
USER_SHELL=$(getent passwd "$REAL_USER" | cut -d: -f7)
SHELL_TYPE=$(basename "${USER_SHELL:-$SHELL}")
echo -e "${GREEN}✅${NC} Configuring for user: $REAL_USER ($REAL_HOME)"
echo -e "${GREEN}✅${NC} Detected shell: $SHELL_TYPE"

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
apt install -y python3-scapy python3-colorama python3-pip 2>/dev/null || {
    echo -e "${YELLOW}⚠️${NC} Some Python packages may already be installed"
}

echo -e "${GREEN}✅${NC} Setting up Python virtual environment..."
if [ ! -d "/opt/hexxFlood-venv" ]; then
    python3 -m venv /opt/hexxFlood-venv 2>/dev/null || {
        echo -e "${YELLOW}⚠️${NC} Virtual environment creation failed - using system Python"
    }
fi

if [ -d "/opt/hexxFlood-venv" ]; then
    source /opt/hexxFlood-venv/bin/activate 2>/dev/null
    pip install --upgrade pip 2>/dev/null
    pip install scapy colorama 2>/dev/null
    deactivate 2>/dev/null
    echo -e "${GREEN}✅${NC} Virtual environment configured at /opt/hexxFlood-venv"
fi

chmod +x "$SCRIPT_DIR/hexxFlood.sh"
echo -e "${GREEN}✅${NC} Made hexxFlood.sh executable"

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

sed -i '/alias hexxFlood=/d' "$RC_FILE" 2>/dev/null
sed -i '/hexxFlood/d' "$RC_FILE" 2>/dev/null

cat >> "$RC_FILE" << 'EOF2'

# hexxFlood Environment
export PATH=$PATH:/usr/local/bin
alias hexxFlood="/usr/local/bin/hexxFlood"

_hexxFlood_completion() {
    local -a commands
    commands=(
        '-t:Target IP'
        '-u:Web URL'
        '--web:Web mode'
        '-p:Threads (1-200)'
        '-s:Packet size'
        '-d:Delay'
        '-i:Interface'
        '-m:Mode (easy,medium,high,extreme,custom)'
        '-P:Ports'
        '-T:Type (syn,udp,icmp,ack,rst,fin,all,http)'
        '-D:Duration'
        '--no-spoof'
        '--fixed-ports'
        '--monitor:Open live monitor only (no attack)'
        '--monitor-mode:Monitor mode (ping,network,system,full,log)'
        '--auto-monitor:Auto-open monitor window(s) on attack start'
        '--no-monitor:Do not auto-open a monitor window'
        '-h:Help'
    )
    compadd -a commands
}
compdef _hexxFlood_completion hexxFlood 2>/dev/null || true
EOF2

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
echo ""
echo "  # Web URL Attack"
echo "  hexxFlood -u http://example.com -m extreme"
echo "  hexxFlood -u https://example.com -T http -p 100"
echo "  hexxFlood -u http://example.com:8080 -m high -D 60"
echo ""
echo -e "${CYAN}📁 Installation Details:${NC}"
echo "  Source Dir:  $SCRIPT_DIR"
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
