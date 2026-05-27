# CDC Testing

Verifies the full pipeline: Oracle DML → GoldenGate Capture → trail files → GoldenGate DAA → RabbitMQ `oracle.cdc` queue.

## Prerequisites

The full stack must be running and both GoldenGate processes (EXT_01, REP_01) must be green before running these tests. See README.md for setup.

---

## Reset before each run

Purge the queue and remove any leftover rows from previous runs:

```
docker exec rabbitmq rabbitmqctl purge_queue oracle.cdc
```

```bash
docker exec -i oracledb sqlplus 'testuser/Welcome123##@//localhost:1521/FREEPDB1' <<EOF
DELETE FROM employees WHERE emp_id != 1;
COMMIT;
EXIT;
EOF
```

---

## Step 1 — Run the SQL test script

The script fires five batches of DML using PL/SQL loops for the heavy batches.

| Batch | Operations | Events |
|---|---|---|
| 1 | 1000 INSERTs (emp_ids 1000–1999) | 1000 |
| 2 | 500 UPDATEs (emp_ids 1000–1499) | 500 |
| 3 | 500 DELETEs (emp_ids 1500–1999) | 500 |
| 4 | 100 I + 100 U + 50 D (emp_ids 2000–2099, single transaction) | 250 |
| 5 | I + U + U + D (emp_id 9999, four separate commits — order test) | 4 |
| **Total** | | **2254** |

```bash
docker exec -i oracledb sqlplus 'testuser/Welcome123##@//localhost:1521/FREEPDB1' \
  < scripts/test_cdc.sql
```

Expected final row count (emp_ids ≥ 1000):

```
remaining_rows
--------------
           550   -- 500 from Batch 2 (1000–1499) + 50 from Batch 4 (2050–2099)
```

---

## Step 2 — Verify messages in RabbitMQ

```bash
./scripts/verify_rabbitmq.sh
```

The script performs five checks against the `oracle.cdc` queue using the RabbitMQ Management API (`ack_requeue_true` — messages are peeked, not consumed).

### Check 1 — Queue depth

Counts messages and compares against the expected 2254.

```
──────────────────────────────────────────
1. Queue depth: oracle.cdc
──────────────────────────────────────────
  Messages in queue : 2254
  Expected          : 2254
  Result            : PASS
```

### Check 2 — Operation type breakdown

Counts messages by `optype`. Expected output:

```
    1101  I
     602  U
     551  D
```

### Check 3 — Raw payloads (first 10)

Prints the first 10 CDC message bodies as JSON for spot-checking. Example INSERT:

```json
{"optype":"I","primarykeys":"1000","after":{"EMP_ID":1000,"NAME":"Emp1000","DEPARTMENT":"Engineering","SALARY":60000}}
```

### Check 4 — Cross-transaction order: emp_id 9999

Verifies that the four separate commits for emp_id 9999 (Batch 5) arrive in the correct order.

```
──────────────────────────────────────────
4. Cross-transaction order: emp_id 9999
──────────────────────────────────────────
  pk=9999  actual=['I', 'U', 'U', 'D']  expected=['I', 'U', 'U', 'D']
  Result : PASS
```

A FAIL here means GoldenGate or RabbitMQ reordered events across commit boundaries.

### Check 5 — Within-transaction order: emp_id 2000

Verifies that INSERT, UPDATE, and DELETE for emp_id 2000 — all within the single Batch 4 commit — arrive in statement-execution order.

```
──────────────────────────────────────────
5. Within-transaction order: emp_id 2000 (Batch 4)
──────────────────────────────────────────
  pk=2000  actual=['I', 'U', 'D']  expected=['I', 'U', 'D']
  Result : PASS
```

A FAIL here means within-transaction event ordering is not preserved.

---

## Manual inspection via RabbitMQ Management UI

Open `http://localhost:15672` (ggadmin / ggadmin123) and navigate to **Queues** → `oracle.cdc`. The **Get Messages** panel lets you inspect individual payloads interactively.