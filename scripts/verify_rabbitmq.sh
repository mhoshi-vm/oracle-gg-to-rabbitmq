#!/bin/bash
# Verify CDC messages landed in RabbitMQ after running test_cdc.sql
# Usage: ./scripts/verify_rabbitmq.sh

USER="ggadmin"
PASS="ggadmin123"
HOST="localhost"
PORT=5672
QUEUE="oracle.cdc"
EXPECTED=100254  # 50000 I + 25000 U + 25000 D + (100 I + 100 U + 50 D) + (1 I + 2 U + 1 D)

sep()  { echo "──────────────────────────────────────────"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

python3 -c "import pika" 2>/dev/null || { echo "pika not installed: pip3 install pika"; exit 1; }

# Consume all messages via AMQP without acknowledging them.
# Closing the connection automatically requeues all unacked messages.
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

python3 - "$HOST" "$PORT" "$USER" "$PASS" "$QUEUE" "$TMPFILE" <<'FETCH_PY'
import sys, json, base64, pika

host, port, user, passwd, queue, outfile = sys.argv[1:]
creds = pika.PlainCredentials(user, passwd)
conn  = pika.BlockingConnection(
    pika.ConnectionParameters(host=host, port=int(port), credentials=creds))
ch = conn.channel()

bodies = []
for method, _, body in ch.consume(queue, auto_ack=False, inactivity_timeout=10):
    if method is None:
        break  # no new messages for 10 s — queue drained
    bodies.append(body)

ch.cancel()
conn.close()  # unacked messages are automatically requeued by the broker

with open(outfile, "w") as f:
    json.dump(
        [{"payload": base64.b64encode(b).decode(), "payload_encoding": "base64"}
         for b in bodies],
        f)
FETCH_PY

# Messages are Java-serialised JMS TextMessage blobs (base64).
# The CDC JSON starts at the first `{"` sequence inside the binary.
EXTRACT_PY='
import sys, json, base64

def load(path):
    with open(path) as f:
        return json.load(f)

def extract(msg):
    p = msg["payload"]
    if msg.get("payload_encoding") == "base64":
        raw = base64.b64decode(p)
        idx = raw.find(b"\x7b\x22")
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
echo "  Expected:   50101 I   25102 U   25051 D"

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

# ── 4. Cross-transaction order: emp_id 99999 (I → U → U → D) ──
sep
bold "4. Cross-transaction order: emp_id 99999"
sep
echo "  Four separate commits must arrive in order: I → U → U → D"
python3 -c "$EXTRACT_PY" "$TMPFILE" check_order "99999" "I,U,U,D"

# ── 5. Within-transaction order: emp_id 60000 (Batch 4) ────────
sep
bold "5. Within-transaction order: emp_id 60000 (Batch 4)"
sep
echo "  INSERT, UPDATE, DELETE within one commit must preserve statement order"
python3 -c "$EXTRACT_PY" "$TMPFILE" check_order "60000" "I,U,D"

sep