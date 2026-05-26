# CDC Testing

Verifies the full pipeline: Oracle DML → GoldenGate Capture → trail files → GoldenGate DAA → RabbitMQ `oracle.cdc` queue.

## Prerequisites

The full stack must be running and both GoldenGate processes (EXT_01, REP_01) must be green before running these tests. See README.md for setup.

---

## Step 1 — Run the SQL test script

The script fires four batches of DML covering every operation type.

| Batch | Operations | Events |
|---|---|---|
| 1 | 4 INSERTs | 4 |
| 2 | 3 UPDATEs | 3 |
| 3 | 2 DELETEs | 2 |
| 4 | 1 INSERT + 1 UPDATE + 1 DELETE (single transaction) | 3 |
| **Total** | | **12** |

Run the script directly from the host by piping it into sqlplus via stdin (`-i`, no `-t`):

```bash
docker exec -i oracledb sqlplus 'testuser/Welcome123##@//localhost:1521/FREEPDB1' \
  < scripts/test_cdc.sql
```

Expected final table state (3 rows):

```bash
docker exec -i oracledb sqlplus 'testuser/Welcome123##@//localhost:1521/FREEPDB1' \
  <<< "SELECT emp_id, name, department, salary FROM employees ORDER BY emp_id;"
```

| EMP_ID | NAME  | DEPARTMENT | SALARY |
|--------|-------|------------|--------|
| 1      | Alice | Engineering | 85000 |
| 11     | Carol | Product     | 72000 |
| 20     | Frank | Sales       | 61000 |

---

## Step 2 — Verify messages in RabbitMQ

Run the verification script from the project root:

```bash
./scripts/verify_rabbitmq.sh
```

The script connects to the RabbitMQ Management API inside the container (no host port required) and performs three checks against the `oracle.cdc` queue.

### Check 1 — Queue depth

Counts messages in `oracle.cdc` and compares against the expected 12.

```
──────────────────────────────────────────
Queue depth: oracle.cdc
──────────────────────────────────────────
  Messages in queue : 12
  Expected          : 12
  Result            : PASS
```

### Check 2 — Raw payloads

Prints each CDC message body as JSON. Each message contains the full row and operation metadata. Example INSERT payload:

```json
{"table":"TESTUSER.EMPLOYEES","op_type":"I","op_ts":"2026-05-26T04:31:23.000000","current_ts":"...","pos":"...","primary_keys":["EMP_ID"],"tokens":{"op_type":"I","primary_keys":"EMP_ID"},"before":null,"after":{"EMP_ID":10,"NAME":"Bob","DEPARTMENT":"Engineering","SALARY":90000}}
```

### Check 3 — Operation type breakdown

Counts messages by `op_type`. Expected output:

```
  4 I
  3 U
  5 D
```

> All checks use `ack_requeue_true` — messages are peeked, not consumed, so the queue depth is unchanged after verification.

---

## Manual inspection via RabbitMQ Management UI

Open `http://localhost:15672` (ggadmin / ggadmin123) and navigate to **Queues** → `oracle.cdc`. The **Get Messages** panel lets you inspect individual payloads interactively.

---

## Resetting between test runs

To clear the queue and reset the table for a clean re-run:

```bash
# Purge the oracle.cdc queue
docker exec rabbitmq rabbitmqadmin purge queue name=oracle.cdc \
  -u ggadmin -p ggadmin123
```

```bash
# Reset the employees table in Oracle
docker exec -it oracledb sqlplus 'testuser/Welcome123##@//localhost:1521/FREEPDB1'
```

```sql
DELETE FROM employees WHERE emp_id != 1;
COMMIT;
```