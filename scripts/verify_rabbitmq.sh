#!/bin/bash
# Verify CDC messages landed in RabbitMQ after running test_cdc.sql
# Usage: ./scripts/verify_rabbitmq.sh

USER="ggadmin"
PASS="ggadmin123"
BASE="http://localhost:15672/api"
QUEUE="oracle.cdc"
EXPECTED=12   # total events from test_cdc.sql (4 INSERT + 3 UPDATE + 2 DELETE + 3 mixed)

sep()  { echo "──────────────────────────────────────────"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# ── 1. Message count ───────────────────────────────────────────
sep
bold "1. Queue depth: $QUEUE"
sep
COUNT=$(curl -sf -u "$USER:$PASS" \
  "$BASE/queues/%2F/$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUEUE'))" 2>/dev/null || echo "$QUEUE")/get" \
  -X POST -H "Content-Type: application/json" \
  -d "{\"count\":100,\"ackmode\":\"ack_requeue_true\",\"encoding\":\"auto\"}" \
  | grep -o '"payload"' | wc -l | tr -d ' ')

echo "  Messages in queue : $COUNT"
echo "  Expected          : $EXPECTED"
[ "$COUNT" -eq "$EXPECTED" ] && echo "  Result            : PASS" || echo "  Result            : FAIL"

# ── 2. Raw payloads ────────────────────────────────────────────
sep
bold "2. Raw CDC payloads (non-destructive peek)"
sep
curl -sf -u "$USER:$PASS" \
  -X POST "$BASE/queues/%2F/$QUEUE/get" \
  -H "Content-Type: application/json" \
  -d "{\"count\":$EXPECTED,\"ackmode\":\"ack_requeue_true\",\"encoding\":\"auto\"}" \
| grep -o '"payload":"[^"]*"' \
| sed 's/"payload":"//;s/"$//' \
| while IFS= read -r msg; do
    printf '%b\n' "$msg"
    echo "---"
  done

# ── 3. Operation breakdown ────────────────────────────────────
sep
bold "3. Operation type counts"
sep
curl -sf -u "$USER:$PASS" \
  -X POST "$BASE/queues/%2F/$QUEUE/get" \
  -H "Content-Type: application/json" \
  -d "{\"count\":$EXPECTED,\"ackmode\":\"ack_requeue_true\",\"encoding\":\"auto\"}" \
| grep -o '"payload":"[^"]*"' \
| sed 's/"payload":"//;s/"$//' \
| while IFS= read -r msg; do printf '%b\n' "$msg"; done \
| grep -o '"op_type":"[^"]*"' \
| sort | uniq -c \
| sed 's/"op_type":"//;s/"//'

sep