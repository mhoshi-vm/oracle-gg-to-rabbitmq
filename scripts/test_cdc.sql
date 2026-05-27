-- =============================================================
-- CDC Test Script — testuser.employees (heavy load)
-- Run via:
--   docker exec -i oracledb sqlplus 'testuser/Welcome123##@//localhost:1521/FREEPDB1' \
--     < scripts/test_cdc.sql
--
-- Purge queue and reset table before each run:
--   docker exec rabbitmq rabbitmqadmin purge queue name=oracle.cdc \
--     -u ggadmin -p ggadmin123
--   docker exec -i oracledb sqlplus 'testuser/Welcome123##@//localhost:1521/FREEPDB1' \
--     <<< "DELETE FROM employees WHERE emp_id >= 1000; COMMIT;"
-- =============================================================

SET DEFINE OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON

-- ── Batch 1: 1000 INSERTs (emp_ids 1000–1999) ────────────────────────────────
-- Expect 1000 INSERT events
DECLARE
  TYPE dept_tab IS TABLE OF VARCHAR2(50) INDEX BY PLS_INTEGER;
  depts dept_tab;
BEGIN
  depts(0) := 'Engineering';
  depts(1) := 'Marketing';
  depts(2) := 'Finance';
  depts(3) := 'Sales';
  depts(4) := 'HR';
  depts(5) := 'Operations';
  depts(6) := 'Legal';
  depts(7) := 'IT';
  depts(8) := 'Support';
  depts(9) := 'Design';
  FOR i IN 1000..1999 LOOP
    INSERT INTO employees VALUES (i, 'Emp' || i, depts(MOD(i, 10)), 50000 + (i * 10));
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Batch 1 done: 1000 INSERTs committed');
END;
/

-- ── Batch 2: 500 UPDATEs (emp_ids 1000–1499) ─────────────────────────────────
-- Expect 500 UPDATE events
BEGIN
  FOR i IN 1000..1499 LOOP
    UPDATE employees SET salary = salary + 5000 WHERE emp_id = i;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Batch 2 done: 500 UPDATEs committed');
END;
/

-- ── Batch 3: 500 DELETEs (emp_ids 1500–1999) ─────────────────────────────────
-- Expect 500 DELETE events
BEGIN
  FOR i IN 1500..1999 LOOP
    DELETE FROM employees WHERE emp_id = i;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Batch 3 done: 500 DELETEs committed');
END;
/

-- ── Batch 4: Large mixed transaction (100 I + 100 U + 50 D = 250 events) ──────
-- All operations in one commit.
-- Within-transaction ordering: INSERTs precede UPDATEs precede DELETEs,
-- matching redo-log statement order.
BEGIN
  FOR i IN 2000..2099 LOOP
    INSERT INTO employees VALUES (i, 'Emp' || i, 'Sales', 60000 + (i * 10));
  END LOOP;
  FOR i IN 2000..2099 LOOP
    UPDATE employees SET salary = salary + 1000 WHERE emp_id = i;
  END LOOP;
  FOR i IN 2000..2049 LOOP
    DELETE FROM employees WHERE emp_id = i;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Batch 4 done: 100 I + 100 U + 50 D committed in one tx');
END;
/

-- ── Batch 5: Transaction-order test (4 separate commits) ─────────────────────
-- emp_id 9999 lifecycle: I → U → U → D across four transactions.
-- verify_rabbitmq.sh check 4 asserts these events arrive in RabbitMQ in this
-- exact order, confirming GoldenGate and RabbitMQ preserve commit ordering.
INSERT INTO employees VALUES (9999, 'Order9999', 'HR', 55000);
COMMIT;
UPDATE employees SET salary     = 56000   WHERE emp_id = 9999;
COMMIT;
UPDATE employees SET department = 'Legal' WHERE emp_id = 9999;
COMMIT;
DELETE FROM employees WHERE emp_id = 9999;
COMMIT;

-- ── Summary ───────────────────────────────────────────────────────────────────
-- Batch | Operations                                    | Events
-- ------|-----------------------------------------------|-------
--     1 | 1000 INSERTs  (1000–1999)                     |  1000
--     2 |  500 UPDATEs  (1000–1499)                     |   500
--     3 |  500 DELETEs  (1500–1999)                     |   500
--     4 | 100 I + 100 U + 50 D  (2000–2099, 1 tx)       |   250
--     5 | I + U + U + D         (9999, 4 tx)             |     4
-- Total |                                               |  2254
--
-- op_type breakdown:  I=1101  U=602  D=551
--
-- Remaining rows (emp_ids >= 1000): 1000–1499, 2050–2099
SELECT COUNT(*) AS remaining_rows
FROM   employees
WHERE  emp_id >= 1000;