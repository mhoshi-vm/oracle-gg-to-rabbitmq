-- Disable variable substitution prompts in SQL*Plus
SET DEFINE OFF;

-- =========================================================
-- CDB Level Configuration
-- =========================================================
-- Enable Minimum Supplemental Logging
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Enable GoldenGate Replication globally
ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=TRUE SCOPE=BOTH;

-- Allocate memory for the LogMiner (Fixes OGG-10556 / OGG-02024)
ALTER SYSTEM SET STREAMS_POOL_SIZE=256M SCOPE=BOTH;

-- Switch session to the Pluggable Database (FREEPDB1)
ALTER SESSION SET CONTAINER = FREEPDB1;

-- =========================================================
-- PDB Level Configuration
-- =========================================================
-- Ensure replication is explicitly enabled at the PDB level too
ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=TRUE SCOPE=BOTH;

-- Ensuer Minimum Supplemental Logging at the PDB level too
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- GoldenGate Admin Setup
CREATE USER ggadmin IDENTIFIED BY Welcome123##;

-- Grant Standard Roles
GRANT CONNECT, RESOURCE, DBA TO ggadmin;
GRANT OGG_CAPTURE TO ggadmin;
GRANT OGG_APPLY TO ggadmin;

-- Grant Explicit Privileges for OCI Background Tasks
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT SELECT ANY TRANSACTION TO ggadmin;
ALTER USER ggadmin QUOTA UNLIMITED ON USERS;

-- Explicit Table & System Privileges
GRANT CREATE TABLE, CREATE ANY TABLE, ALTER ANY TABLE, DROP ANY TABLE TO ggadmin;
GRANT SELECT ANY TABLE, INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE TO ggadmin;
GRANT EXECUTE ON DBMS_FLASHBACK TO ggadmin;
GRANT EXECUTE ON DBMS_XSTREAM_GG_ADM TO ggadmin;
GRANT EXECUTE ON DBMS_CAPTURE_ADM TO ggadmin;
GRANT EXECUTE_CATALOG_ROLE TO ggadmin;

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

-- Enable table-level supplemental logging
ALTER TABLE testuser.employees ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Insert a test record
INSERT INTO testuser.employees (emp_id, name, department, salary)
VALUES (1, 'Alice', 'Engineering', 85000);

COMMIT;