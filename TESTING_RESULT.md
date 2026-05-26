# The below is the actual testing result

```
$ ./scripts/verify_rabbitmq.sh
──────────────────────────────────────────
1. Queue depth: oracle.cdc
──────────────────────────────────────────
  Messages in queue : 12
  Expected          : 12
  Result            : PASS
──────────────────────────────────────────
2. Raw CDC payloads (non-destructive peek)
──────────────────────────────────────────
{"optype":"I","primarykeys":"2","after":{"EMP_ID":2,"NAME":"Bob","DEPARTMENT":"Marketing","SALARY":75000}}
---
{"optype":"I","primarykeys":"3","after":{"EMP_ID":3,"NAME":"Carol","DEPARTMENT":"Sales","SALARY":65000}}
---
{"optype":"I","primarykeys":"10","after":{"EMP_ID":10,"NAME":"Bob","DEPARTMENT":"Engineering","SALARY":90000}}
---
{"optype":"I","primarykeys":"11","after":{"EMP_ID":11,"NAME":"Carol","DEPARTMENT":"Marketing","SALARY":72000}}
---
{"optype":"I","primarykeys":"12","after":{"EMP_ID":12,"NAME":"Dave","DEPARTMENT":"Finance","SALARY":68000}}
---
{"optype":"I","primarykeys":"13","after":{"EMP_ID":13,"NAME":"Eve","DEPARTMENT":"Engineering","SALARY":95000}}
---
{"optype":"U","primarykeys":"10","before":{"EMP_ID":10,"NAME":"Bob","DEPARTMENT":"Engineering","SALARY":90000},"after":{"EMP_ID":10,"SALARY":96000}}
---
{"optype":"U","primarykeys":"11","before":{"EMP_ID":11,"NAME":"Carol","DEPARTMENT":"Marketing","SALARY":72000},"after":{"EMP_ID":11,"DEPARTMENT":"Product"}}
---
{"optype":"U","primarykeys":"12","before":{"EMP_ID":12,"NAME":"Dave","DEPARTMENT":"Finance","SALARY":68000},"after":{"EMP_ID":12,"NAME":"David","SALARY":70000}}
---
{"optype":"D","primarykeys":"13","before":{"EMP_ID":13,"NAME":"Eve","DEPARTMENT":"Engineering","SALARY":95000}}
---
{"optype":"D","primarykeys":"12","before":{"EMP_ID":12,"NAME":"David","DEPARTMENT":"Finance","SALARY":70000}}
---
{"optype":"I","primarykeys":"20","after":{"EMP_ID":20,"NAME":"Frank","DEPARTMENT":"Sales","SALARY":60000}}
---
──────────────────────────────────────────
3. Operation type counts
──────────────────────────────────────────
    2  D
    7  I
    3  U
──────────────────────────────────────────
```