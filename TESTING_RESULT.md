# The below is the actual testing result

```
──────────────────────────────────────────
1. Queue depth: oracle.cdc
──────────────────────────────────────────
  Messages in queue : 2254
  Expected          : 2254
  Result            : PASS
──────────────────────────────────────────
2. Operation type counts
──────────────────────────────────────────
    551  D
   1101  I
    602  U

  Expected:   1101 I   602 U   551 D
──────────────────────────────────────────
3. Raw CDC payloads (first 10, non-destructive peek)
──────────────────────────────────────────
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
{"optype":"I","primarykeys":"1005","after":{"EMP_ID":1005,"NAME":"Emp1005","DEPARTMENT":"Operations","SALARY":60050}}
---
{"optype":"I","primarykeys":"1006","after":{"EMP_ID":1006,"NAME":"Emp1006","DEPARTMENT":"Legal","SALARY":60060}}
---
{"optype":"I","primarykeys":"1007","after":{"EMP_ID":1007,"NAME":"Emp1007","DEPARTMENT":"IT","SALARY":60070}}
---
{"optype":"I","primarykeys":"1008","after":{"EMP_ID":1008,"NAME":"Emp1008","DEPARTMENT":"Support","SALARY":60080}}
---
{"optype":"I","primarykeys":"1009","after":{"EMP_ID":1009,"NAME":"Emp1009","DEPARTMENT":"Design","SALARY":60090}}
---
──────────────────────────────────────────
4. Cross-transaction order: emp_id 9999
──────────────────────────────────────────
  Four separate commits must arrive in order: I → U → U → D
  pk=9999  actual=['I', 'U', 'U', 'D']  expected=['I', 'U', 'U', 'D']
  Result : PASS
──────────────────────────────────────────
5. Within-transaction order: emp_id 2000 (Batch 4)
──────────────────────────────────────────
  INSERT, UPDATE, DELETE within one commit must preserve statement order
  pk=2000  actual=['I', 'U', 'D']  expected=['I', 'U', 'D']
  Result : PASS
──────────────────────────────────────────
```