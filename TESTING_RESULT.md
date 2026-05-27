# The below is the actual testing result

```
──────────────────────────────────────────
1. Queue depth: oracle.cdc
──────────────────────────────────────────
  Messages in queue : 100254
  Expected          : 100254
  Result            : PASS
──────────────────────────────────────────
2. Operation type counts
──────────────────────────────────────────
  25051  D
  50101  I
  25102  U

  Expected:   50101 I   25102 U   25051 D
──────────────────────────────────────────
3. Raw CDC payloads (first 10, non-destructive peek)
──────────────────────────────────────────
  -- optype=D --
{"optype":"D","primarykeys":"26000","before":{"EMP_ID":26000,"NAME":"Emp26000","DEPARTMENT":"Engineering","SALARY":310000}}
---
{"optype":"D","primarykeys":"26001","before":{"EMP_ID":26001,"NAME":"Emp26001","DEPARTMENT":"Marketing","SALARY":310010}}
---
{"optype":"D","primarykeys":"26002","before":{"EMP_ID":26002,"NAME":"Emp26002","DEPARTMENT":"Finance","SALARY":310020}}
---
{"optype":"D","primarykeys":"26003","before":{"EMP_ID":26003,"NAME":"Emp26003","DEPARTMENT":"Sales","SALARY":310030}}
---
{"optype":"D","primarykeys":"26004","before":{"EMP_ID":26004,"NAME":"Emp26004","DEPARTMENT":"HR","SALARY":310040}}
---
  -- optype=I --
{"optype":"I","primarykeys":"1000","after":{"EMP_ID":1000,"NAME":"Emp1000","DEPARTMENT":"Engineering","SALARY":60000}}
---
{"optype":"I","primarykeys":"1001","after":{"EMP_ID":1001,"NAME":"Emp1001","DEPARTMENT":"Marketing","SALARY":60010}}
---
{"optype":"I","primarykeys":"1002","after":{"EMP_ID":1002,"NAME":"Emp1002","DEPARTMENT":"Finance","SALARY":60020}}
---
{"optype":"I","primarykeys":"1003","after":{"EMP_ID":1003,"NAME":"Emp1003","DEPARTMENT":"Sales","SALARY":60030}}
---
{"optype":"I","primarykeys":"1004","after":{"EMP_ID":1004,"NAME":"Emp1004","DEPARTMENT":"HR","SALARY":60040}}
---
  -- optype=U --
{"optype":"U","primarykeys":"1000","before":{"EMP_ID":1000,"NAME":"Emp1000","DEPARTMENT":"Engineering","SALARY":60000},"after":{"EMP_ID":1000,"SALARY":65000}}
---
{"optype":"U","primarykeys":"1001","before":{"EMP_ID":1001,"NAME":"Emp1001","DEPARTMENT":"Marketing","SALARY":60010},"after":{"EMP_ID":1001,"SALARY":65010}}
---
{"optype":"U","primarykeys":"1002","before":{"EMP_ID":1002,"NAME":"Emp1002","DEPARTMENT":"Finance","SALARY":60020},"after":{"EMP_ID":1002,"SALARY":65020}}
---
{"optype":"U","primarykeys":"1003","before":{"EMP_ID":1003,"NAME":"Emp1003","DEPARTMENT":"Sales","SALARY":60030},"after":{"EMP_ID":1003,"SALARY":65030}}
---
{"optype":"U","primarykeys":"1004","before":{"EMP_ID":1004,"NAME":"Emp1004","DEPARTMENT":"HR","SALARY":60040},"after":{"EMP_ID":1004,"SALARY":65040}}
---
──────────────────────────────────────────
4. Cross-transaction order: emp_id 99999
──────────────────────────────────────────
  Four separate commits must arrive in order: I → U → U → D
  pk=99999  actual=['I', 'U', 'U', 'D']  expected=['I', 'U', 'U', 'D']
  Result : PASS
──────────────────────────────────────────
5. Within-transaction order: emp_id 60000 (Batch 4)
──────────────────────────────────────────
  INSERT, UPDATE, DELETE within one commit must preserve statement order
  pk=60000  actual=['I', 'U', 'D']  expected=['I', 'U', 'D']
  Result : PASS
──────────────────────────────────────────
```