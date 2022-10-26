# App Insights and Java
https://learn.microsoft.com/en-us/azure/azure-monitor/app/java-in-process-agent

* Main method is to use the -javaagent command at start up
```
java -javaagent:/opt/target/applicationinsights-agent-3.X.X.jar -jar app.jar
```

* Alternative is to use the runtime-attach dependency https://learn.microsoft.com/en-us/azure/azure-monitor/app/java-spring-boot#enabling-programmatically
```
<dependency>
    <groupId>com.microsoft.azure</groupId>
    <artifactId>applicationinsights-runtime-attach</artifactId>
    <version>3.4.2</version>
</dependency>
```