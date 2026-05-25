-- =========================================================
-- 01_setup_cdc.sql
-- Runs automatically on initial DB creation in Docker
-- =========================================================

-- Enable Minimum Supplemental Logging at the CDB level
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Switch session to the Pluggable Database (FREEPDB1)
ALTER SESSION SET CONTAINER = FREEPDB1;

-- =========================================================
-- GoldenGate Admin Setup
-- =========================================================
CREATE USER ggadmin IDENTIFIED BY Welcome123##;
GRANT CONNECT, RESOURCE TO ggadmin;
GRANT OGG_CAPTURE TO ggadmin;  -- 23ai Role for Extract
GRANT OGG_APPLY TO ggadmin;    -- 23ai Role for Replicat
GRANT DBA TO ggadmin;          -- Optional: Added for testing ease

-- =========================================================
-- Source Schema and Table Setup
-- =========================================================
CREATE USER testuser IDENTIFIED BY Welcome123## QUOTA UNLIMITED ON USERS;
GRANT CONNECT, RESOURCE TO testuser;

CREATE TABLE testuser.employees (
    emp_id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    department VARCHAR2(50),
    salary NUMBER
);

-- Enable table-level supplemental logging (required for CDC)
ALTER TABLE testuser.employees ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Insert a test record
INSERT INTO testuser.employees (emp_id, name, department, salary)
VALUES (1, 'Alice', 'Engineering', 85000);

COMMIT;