-- =========================================================
-- 01_setup_cdc.sql
-- Runs automatically on initial DB creation in Docker
-- =========================================================

-- Disable variable substitution prompts in SQL*Plus
SET DEFINE OFF;

-- Enable Minimum Supplemental Logging at the CDB level
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Switch session to the Pluggable Database (FREEPDB1)
ALTER SESSION SET CONTAINER = FREEPDB1;

ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=TRUE SCOPE=BOTH;

-- =========================================================
-- GoldenGate Admin Setup
-- =========================================================
CREATE USER ggadmin IDENTIFIED BY Welcome123##;

-- Grant standard connectivity and DBA roles
GRANT CONNECT, RESOURCE, DBA TO ggadmin;

-- Grant 23ai specific GoldenGate roles
GRANT OGG_CAPTURE TO ggadmin;  -- Required for Extract
GRANT OGG_APPLY TO ggadmin;    -- Required for Replicat

-- Grant explicit dictionary access (Fixes ORA-00942 on SYS.V_$INSTANCE)
GRANT SELECT ANY DICTIONARY TO ggadmin;

-- Grant explicit execution on the required Streams/Capture packages
GRANT EXECUTE ON DBMS_XSTREAM_GG_ADM TO ggadmin;
GRANT EXECUTE ON DBMS_CAPTURE_ADM TO ggadmin;

-- Grant the catalog role as a fallback for other system package queries
GRANT EXECUTE_CATALOG_ROLE TO ggadmin;

-- 1. Give ggadmin explicit storage quota (Roles do not grant quota in OCI)
ALTER USER ggadmin QUOTA UNLIMITED ON USERS;

-- 2. Grant explicit table creation and alteration privileges
GRANT CREATE TABLE TO ggadmin;
GRANT CREATE ANY TABLE TO ggadmin;
GRANT ALTER ANY TABLE TO ggadmin;
GRANT DROP ANY TABLE TO ggadmin;

-- 3. Grant explicit DML privileges for the Replicat to update checkpoints
GRANT SELECT ANY TABLE, INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE TO ggadmin;

-- 4. Grant Flashback (required for some OGG checkpoint synchronizations)
GRANT EXECUTE ON DBMS_FLASHBACK TO ggadmin;

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