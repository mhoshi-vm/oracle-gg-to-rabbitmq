- Only works on Linux
- Uses commercial Oracle DAA, make sure no license violation

# Download RabbitMQ JMS Client and dependencies

```
mvn clean dependency:copy-dependencies -DoutputDirectory=./gg_jars -DincludeScope=runtime
```

https://192.168.0.106:8444/services/Local/adminsrvr/v2/content/#/dbConnections