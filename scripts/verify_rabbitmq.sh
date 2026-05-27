#!/bin/bash
# Verify CDC messages landed in RabbitMQ after running test_cdc.sql
# Usage: ./scripts/verify_rabbitmq.sh

USER="ggadmin"
PASS="ggadmin123"
BASE="http://localhost:15672/api"
QUEUE="oracle.cdc"
EXPECTED=2254   # 1000 I + 500 U + 500 D + (100 I + 100 U + 50 D) + (1 I + 2 U + 1 D)

sep()  { echo "──────────────────────────────────────────"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# Fetch all messages into a temp file to avoid ARG_MAX limits on large payloads.
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

curl -sf -u "$USER:$PASS" \
  -X POST "$BASE/queues/%2F/$QUEUE/get" \
  -H "Content-Type: application/json" \
  -d "{\"count\":$EXPECTED,\"ackmode\":\"ack_requeue_true\",\"encoding\":\"auto\"}" \
  > "$TMPFILE"

# Messages are Java-serialised JMS TextMessage blobs (base64).
# The CDC JSON is embedded at the end of each binary after the first '{'.
EXTRACT_PY='
import sys, json, base64

def load(path):
    with open(path) as f:
        return json.load(f)

def extract(msg):
    p = msg["payload"]
    if msg.get("payload_encoding") == "base64":
        raw = base64.b64decode(p)
        idx = raw.find(b'{\x22')
        return raw[idx:].decode("utf-8", errors="ignore") if idx >= 0 else None
    return p

def parsed_events(messages):
    events = []
    for m in messages:
        j = extract(m)
        if j:
            try:
                events.append(json.loads(j))
            except Exception:
                pass
    return events

messages = load(sys.argv[1])
mode     = sys.argv[2]

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
    ops = [e.get("optype", "?") for e in parsed_events(messages)]
    for op, n in sorted(Counter(ops).items()):
        print(f"  {n:5d}  {op}")

elif mode == "check_order":
    # argv[3] = primary key value (string)
    # argv[4] = comma-separated expected op sequence, e.g. "I,U,U,D"
    pk       = sys.argv[3]
    expected = sys.argv[4].split(",")
    actual   = [
        e.get("optype", "?")
        for e in parsed_events(messages)
        if str(e.get("primarykeys", "")) == pk
    ]
    print(f"  pk={pk}  actual={actual}  expected={expected}")
    if actual == expected:
        print("  Result : PASS")
    else:
        print("  Result : FAIL")
'

# ── 1. Queue depth ─────────────────────────────────────────────
sep
bold "1. Queue depth: $QUEUE"
sep
COUNT=$(python3 -c "$EXTRACT_PY" "$TMPFILE" count)
echo "  Messages in queue : $COUNT"
echo "  Expected          : $EXPECTED"
[ "$COUNT" -eq "$EXPECTED" ] && echo "  Result            : PASS" || echo "  Result            : FAIL"

# ── 2. Operation type breakdown ────────────────────────────────
sep
bold "2. Operation type counts"
sep
python3 -c "$EXTRACT_PY" "$TMPFILE" ops
echo ""
echo "  Expected:   1101 I   602 U   551 D"

# ── 3. Raw payloads (first 10 messages) ───────────────────────
sep
bold "3. Raw CDC payloads (first 10, non-destructive peek)"
sep
python3 - "$TMPFILE" <<'PYEOF'
import sys, json, base64

def extract(msg):
    p = msg["payload"]
    if msg.get("payload_encoding") == "base64":
        raw = base64.b64decode(p)
        idx = raw.find(b'{"')
        return raw[idx:].decode("utf-8", errors="ignore") if idx >= 0 else None
    return p

with open(sys.argv[1]) as f:
    messages = json.load(f)

for m in messages[:10]:
    j = extract(m)
    if j:
        print(j)
        print("---")
PYEOF

# ── 4. Cross-transaction order: emp_id 9999 (I → U → U → D) ───
sep
bold "4. Cross-transaction order: emp_id 9999"
sep
echo "  Four separate commits must arrive in order: I → U → U → D"
python3 -c "$EXTRACT_PY" "$TMPFILE" check_order "9999" "I,U,U,D"

# ── 5. Within-transaction order: emp_id 2000 (I → U → D) ──────
sep
bold "5. Within-transaction order: emp_id 2000 (Batch 4)"
sep
echo "  INSERT, UPDATE, DELETE within one commit must preserve statement order"
python3 -c "$EXTRACT_PY" "$TMPFILE" check_order "2000" "I,U,D"

sep