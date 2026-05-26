-- =============================================================
-- CDC Test Script — testuser.employees
-- Run via:
--   docker exec -it oracledb sqlplus 'testuser/Welcome123##@//localhost:1521/FREEPDB1' @/tmp/test_cdc.sql
-- Or paste interactively after connecting with sqlplus.
-- =============================================================

SET DEFINE OFF
SET FEEDBACK ON

-- ── Batch 1: INSERTs ──────────────────────────────────────────
-- Expect 4 INSERT events in RabbitMQ
INSERT INTO employees (emp_id, name, department, salary) VALUES (10, 'Bob',     'Engineering', 90000);
INSERT INTO employees (emp_id, name, department, salary) VALUES (11, 'Carol',   'Marketing',   72000);
INSERT INTO employees (emp_id, name, department, salary) VALUES (12, 'Dave',    'Finance',     68000);
INSERT INTO employees (emp_id, name, department, salary) VALUES (13, 'Eve',     'Engineering', 95000);
COMMIT;

-- ── Batch 2: UPDATEs ─────────────────────────────────────────
-- Expect 3 UPDATE events in RabbitMQ
UPDATE employees SET salary = 96000                  WHERE emp_id = 10;
UPDATE employees SET department = 'Product'          WHERE emp_id = 11;
UPDATE employees SET salary = 70000, name = 'David'  WHERE emp_id = 12;
COMMIT;

-- ── Batch 3: DELETEs ─────────────────────────────────────────
-- Expect 2 DELETE events in RabbitMQ
DELETE FROM employees WHERE emp_id = 13;
DELETE FROM employees WHERE emp_id = 12;
COMMIT;

-- ── Batch 4: Mixed single transaction ────────────────────────
-- Expect 3 events (1 INSERT + 1 UPDATE + 1 DELETE) in one tx
INSERT INTO employees (emp_id, name, department, salary) VALUES (20, 'Frank', 'Sales', 60000);
UPDATE employees SET salary = 61000 WHERE emp_id = 20;
DELETE FROM employees WHERE emp_id = 10;
COMMIT;

-- ── Final state ───────────────────────────────────────────────
-- Total events expected: 4 + 3 + 2 + 3 = 12
-- Remaining rows: emp_id 1 (Alice), 11 (Carol/Product), 20 (Frank)
SELECT emp_id, name, department, salary FROM employees ORDER BY emp_id;