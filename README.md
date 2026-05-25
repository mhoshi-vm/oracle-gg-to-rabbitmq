- Only works on Linux
- Uses commercial Oracle DAA, make sure no license violation

# Download RabbitMQ JMS Client and dependencies

```
mvn clean dependency:copy-dependencies -DoutputDirectory=./gg_jars -DincludeScope=runtime
```

# Setup Oracle DB

Login to Oracle DB 

```
docker exec -it oracle-db sqlplus 'sys/OraclePassword1!@localhost:1521/FREE as sysdba'
```

Create new Database

```
-- 1. Switch to the Root Container to enable system-wide logging
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER DATABASE FORCE LOGGING;

-- 2. Switch back to your Pluggable Database to create your user and tables
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- 3. Create the user (Note the double quotes around the password!)
CREATE USER cdc_test IDENTIFIED BY "Password123!";
GRANT CONNECT, RESOURCE, DBA TO cdc_test;
ALTER USER cdc_test QUOTA UNLIMITED ON USERS;

-- 4. Create the test table
CREATE TABLE cdc_test.customers (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(50),
    email VARCHAR2(50),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

