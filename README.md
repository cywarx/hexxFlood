# 💀 hexxFlood - Ultimate Network Stress Testing Tool

[![Version](https://img.shields.io/badge/version-1.0-red.svg)](https://github.com/Cywarx/hexxFlood)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Kali](https://img.shields.io/badge/Kali-Linux-blue.svg)](https://www.kali.org/)
[![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)](https://www.gnu.org/software/bash/)

## ⚠️ DISCLAIMER

**THIS TOOL IS FOR EDUCATIONAL AND LEGITIMATE TESTING PURPOSES ONLY!**

- ✅ **ONLY** use on networks you **OWN** or have **EXPLICIT WRITTEN PERMISSION** to test
- ❌ Unauthorized use is **ILLEGAL** and can result in severe penalties
- 👮‍♂️ You are **SOLELY RESPONSIBLE** for your actions
- ⚖️ The author takes **NO responsibility** for misuse
- 🛡️ Use responsibly and ethically

> **DEMO NOTE:** For the live demonstration, run this **only** against your own
> lab/target machine on an **isolated network you control** (e.g. an air-gapped switch or
> a dedicated demo VLAN). Never point it at conference/venue infrastructure or any shared network.

---

## 🚀 Features

### Core Features
- ✅ **6 Attack Types** (SYN, UDP, ICMP, ACK, RST, FIN)
- ✅ **5 Attack Modes** (Easy, Medium, High, Extreme, Custom)
- ✅ **Configurable Threads** (1-200)
- ✅ **Custom Port Selection**
- ✅ **IP Spoofing**
- ✅ **Real-time Monitoring**
- ✅ **Automatic Cleanup**
- ✅ **Configuration Persistence**
- ✅ **System Optimization**

### Web & HTTP Features
- 🌐 **Web URL Support** (HTTP/HTTPS)
- 🔥 **HTTP Flood Attack**
- 🔄 **User-Agent Rotation**
- 📊 **Real-time Packet Counting**
- 📈 **Packets Per Second (PPS) Tracking**
- 🌊 **Bandwidth Estimation**
- 🎯 **Domain to IP Resolution**
- 🔒 **SSL/TLS Support**
- 📱 **Multi-threaded HTTP Requests**

---

## 📦 Installation

### Quick Install (Recommended)

```bash
# Clone the repository
git clone https://github.com/Cywarx/hexxFlood.git
cd hexxFlood

# Run setup (installs hping3, python deps, etc.)
sudo ./setup.sh

# Verify installation
hexxFlood -h
```

### Updating

Pull the latest version straight from the tool — no need to re-clone:

```bash
hexxFlood --update        # or: hexxFlood -U
./quick.sh update         # same thing via the quick launcher
```

This runs a fast-forward `git pull` in the install directory and re-applies the
executable bit. If you have local edits that conflict, it tells you how to reset.

---

## 🎮 Usage

```bash
sudo ./hexxFlood.sh [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `-t, --target IP`       | Target IP address |
| `-u, --url URL`         | Target Web URL (`http://example.com`) |
| `-p, --threads NUM`     | Number of threads (1-200, default: 50) |
| `-s, --size BYTES`      | Packet size (64-65495, default: 65495) |
| `-d, --delay MS`        | Delay (`u1`, `u10`, `u100`, default: `u1`) |
| `-i, --interface IFACE` | Network interface (default: `wlan0`) |
| `-m, --mode MODE`       | Mode: `easy` \| `medium` \| `high` \| `extreme` \| `custom` |
| `-P, --ports PORTS`     | Comma-separated dst ports — floods **each** port (e.g. `80,443,22`) |
| `-T, --type TYPES`      | Types: `syn,udp,icmp,ack,rst,fin,all,http` |
| `-D, --duration SEC`    | Duration in seconds (0 = infinite) |
| `--no-spoof`            | Disable source-IP spoofing (drops `--rand-source`) |
| `--fixed-ports`         | Use a static dst port instead of an incrementing one |
| `-U, --update`          | Update hexxFlood to the latest version (`git pull`) |
| `-V, --version`         | Show version and exit |
| `-h, --help`            | Show help |

### Attack Modes

| Mode | Threads | Delay | Attack Types |
|------|---------|-------|--------------|
| `easy`    | 10  | `u100` | syn, udp, icmp |
| `medium`  | 25  | `u10`  | syn, udp, icmp, ack |
| `high`    | 50  | `u1`   | syn, udp, icmp, ack, rst, fin |
| `extreme` | 100 | `u1`   | all |
| `custom`  | —   | —      | your own `-p / -d / -T` values |

### Examples

```bash
# SYN flood against a lab target for 60 seconds
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn -m high -D 60

# Multi-port flood — hits 80, 443 and 22 simultaneously
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn -P 80,443,22 -p 100

# No spoofing (real source IP) with a fixed destination port
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn --no-spoof --fixed-ports

# HTTP flood against a web app
sudo ./hexxFlood.sh -u http://192.168.1.14 -T http -p 100

# All attack types, extreme mode
sudo ./hexxFlood.sh -t 192.168.1.14 -T all -m extreme
```

### Quick Launcher (`quick.sh`)

Preset one-liners for common scenarios:

```bash
./quick.sh local             # extreme attack on default lab target
./quick.sh local-test        # easy 30s smoke test
./quick.sh web http://target # extreme web flood
./quick.sh lab 10.0.0.5      # high-mode attack on ports 80,443,22
./quick.sh custom            # interactive prompts
./quick.sh status            # is anything running?
./quick.sh stop              # kill all attacks
```

---

## 📊 Monitoring the Attack (Live Demo)

The repo ships a dedicated **`monitor.sh`** script so you can *demonstrate the impact* of the
attack in real time — perfect for a side-by-side split screen during the talk:
**left pane = attack (`hexxFlood.sh`), right pane = monitor (`monitor.sh`).**

### Zero-effort monitoring — built into `hexxFlood`

You no longer need to open the monitor by hand. It is wired straight into the main tool:

```bash
# Watch a target only (no attack) — same as running monitor.sh
hexxFlood --monitor -t 192.168.1.14
hexxFlood --monitor --monitor-mode ping -t 192.168.1.14

# Launch an attack: a monitor terminal opens AUTOMATICALLY
hexxFlood -t 192.168.1.14 -m extreme

# Open several monitor windows at once (one per mode)
hexxFlood -t 192.168.1.14 -m extreme --auto-monitor full,ping,system

# Don't auto-open anything (attack only, current terminal)
hexxFlood -t 192.168.1.14 -m extreme --no-monitor
```

| Option | Description |
|--------|-------------|
| `--monitor`            | Open the live monitor only, no attack (uses `-t`/`-i`) |
| `--monitor-mode MODE`  | Mode for `--monitor`: `ping`\|`network`\|`system`\|`full`\|`log` (default `full`) |
| `--auto-monitor [MODES]` | Auto-open monitor window(s) when an attack starts. `MODES` is comma-separated → one window each. **On by default** (`full`) |
| `--no-monitor`         | Do not auto-open any monitor window |

The auto-opened windows launch in whatever terminal emulator you have
(`xterm`, `gnome-terminal`, `konsole`, `xfce4-terminal`, `qterminal`, `kitty`,
`alacritty`, `tilix`, …) and run as your normal user even though the attack runs under `sudo`.

> **Headless / SSH boxes:** if no graphical display is available, the monitor windows are
> simply skipped with a notice — **the attack still runs at full power in your single terminal**.
> Open a monitor by hand in another SSH session with `hexxFlood --monitor -t <ip>` if you want one.

### Recommended demo layout

```
┌───────────────────────────────┬───────────────────────────────┐
│  ATTACKER PANE                 │  MONITOR PANE                  │
│  sudo ./hexxFlood.sh \         │  ./monitor.sh \                │
│    -t 192.168.1.14 -T syn \    │    -t 192.168.1.14 \           │
│    -m high -D 120              │    -i wlan0 -m full            │
└───────────────────────────────┴───────────────────────────────┘
```

Use `tmux` (or two terminals) to show both at once:

```bash
tmux new-session -d -s demo
tmux split-window -h
tmux send-keys -t demo:0.0 'sudo ./hexxFlood.sh -t 192.168.1.14 -T syn -m high -D 120' C-m
tmux send-keys -t demo:0.1 './monitor.sh -t 192.168.1.14 -i wlan0 -m full' C-m
tmux attach -t demo
```

### Monitor usage

```bash
./monitor.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `-t, --target IP`       | Target IP to monitor (default: `192.168.1.14`) |
| `-i, --interface IFACE` | Network interface (default: `wlan0`) |
| `-m, --mode MODE`       | `ping` \| `network` \| `system` \| `full` \| `log` |
| `-h, --help`            | Show help |

### Monitor modes — what each one *shows the audience*

| Mode | What it demonstrates | Command |
|------|----------------------|---------|
| **`ping`**    | Target latency spiking / **going unresponsive** — the clearest "it's down" signal | `./monitor.sh -t 192.168.1.14 -m ping` |
| **`network`** | TX/RX packet counters climbing, active connections, live `hping3` process count | `./monitor.sh -i wlan0 -m network` |
| **`system`**  | CPU/RAM/load spiking + top attack processes on the *attacker* box | `./monitor.sh -m system` |
| **`full`**    | **All of the above on one dashboard** — the go-to view for the live demo | `./monitor.sh -t 192.168.1.14 -i wlan0 -m full` |
| **`log`**     | Timestamps everything to `hexxFlood_monitor_<date>.log` for post-demo evidence | `./monitor.sh -t 192.168.1.14 -m log` |

### Step-by-step: demonstrating the DoS live

1. **Baseline first (before attacking).** Start the monitor and let the audience see a
   *healthy* target — low ping (`time=X ms`), flat packet counters, normal CPU:
   ```bash
   ./monitor.sh -t 192.168.1.14 -i wlan0 -m full
   ```
2. **Launch the attack** in the second pane:
   ```bash
   sudo ./hexxFlood.sh -t 192.168.1.14 -T syn -m high -D 120
   ```
3. **Watch the impact** on the monitor pane:
   - Ping latency climbs, then flips to **`💀 TARGET UNRESPONSIVE!`**
   - `TX packets` / `RX packets` counters race upward
   - `hping3 Processes` and `Active Connections` jump
   - Attacker CPU / Load Average spike
4. **Stop the attack** — either wait for `-D` duration to elapse, or `Ctrl+C` the attacker pane.
5. **Show recovery** — ping returns to normal, proving the target was only down *during* the attack.
6. **(Optional) Keep evidence** — run a parallel `log` monitor so you have a timestamped file
   to reference in Q&A:
   ```bash
   ./monitor.sh -t 192.168.1.14 -m log
   ```

### Verifying impact with standard tools (backup / cross-check)

If you want additional, non-custom tooling on screen for credibility:

```bash
# Continuous latency graph
ping 192.168.1.14

# Live per-second interface throughput
sudo iftop -i wlan0                 # or: sudo nload wlan0

# Live packet capture proving the flood
sudo tcpdump -i wlan0 host 192.168.1.14 -nn

# Watch connection/socket counts climb
watch -n1 'ss -s'
```

> **Tip:** For SYN floods, run `tcpdump` on the **target** to show a storm of half-open
> `[S]` packets with spoofed source IPs — very visual for an audience.

---

## 🧹 Cleanup

`hexxFlood.sh` cleans up its own child processes on exit. If anything is left running:

```bash
sudo pkill hping3
sudo pkill -f http_flood.py
```

---

## 📄 License

Released under the [MIT License](LICENSE).
