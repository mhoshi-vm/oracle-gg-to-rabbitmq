#!/bin/bash
# Verify CDC messages landed in RabbitMQ after running test_cdc.sql
# Usage: ./scripts/verify_rabbitmq.sh

USER="ggadmin"
PASS="ggadmin123"
BASE="http://localhost:15672/api"
QUEUE="oracle.cdc"
EXPECTED=12   # 4 INSERT + 3 UPDATE + 2 DELETE + 3 mixed

sep()  { echo "──────────────────────────────────────────"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

RESPONSE=$(curl -sf -u "$USER:$PASS" \
  -X POST "$BASE/queues/%2F/$QUEUE/get" \
  -H "Content-Type: application/json" \
  -d "{\"count\":$EXPECTED,\"ackmode\":\"ack_requeue_true\",\"encoding\":\"auto\"}")

# Messages are Java-serialised JMS TextMessage blobs (base64).
# The CDC JSON is embedded at the end of each binary after the first '{'.
EXTRACT_PY='
import sys, json, base64

def extract(msg):
    p = msg["payload"]
    if msg.get("payload_encoding") == "base64":
        raw = base64.b64decode(p)
        idx = raw.find(b"{")
        return raw[idx:].decode("utf-8", errors="ignore") if idx >= 0 else None
    return p

messages = json.loads(sys.argv[1])
mode = sys.argv[2]

if mode == "count":
    print(len(messages))
elif mode == "payloads":
    for m in messages:
        j = extract(m)
        if j:
            print(j)
            print("---")
elif mode == "ops":
    from collections import Counter
    ops = []
    for m in messages:
        j = extract(m)
        if j:
            try:
                ops.append(json.loads(j).get("optype", "?"))
            except Exception:
                pass
    for op, n in sorted(Counter(ops).items()):
        print(f"  {n:3d}  {op}")
'

# ── 1. Queue depth ─────────────────────────────────────────────
sep
bold "1. Queue depth: $QUEUE"
sep
COUNT=$(python3 -c "$EXTRACT_PY" "$RESPONSE" count)
echo "  Messages in queue : $COUNT"
echo "  Expected          : $EXPECTED"
[ "$COUNT" -eq "$EXPECTED" ] && echo "  Result            : PASS" || echo "  Result            : FAIL"

# ── 2. Raw payloads ────────────────────────────────────────────
sep
bold "2. Raw CDC payloads (non-destructive peek)"
sep
python3 -c "$EXTRACT_PY" "$RESPONSE" payloads

# ── 3. Operation type breakdown ────────────────────────────────
sep
bold "3. Operation type counts"
sep
python3 -c "$EXTRACT_PY" "$RESPONSE" ops

sep