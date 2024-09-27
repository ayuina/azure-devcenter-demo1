# Configuration



# SQL Database Connection String

Connection String can be read from `sqlconstr` environment variable on Azure App Service.
Your application should read and use it.

```csharp
// Environment Variable
var constr = Environment.GetEnvironmentVariables("sqlconstr")

// Configuration
var constr = IConfigurationp["sqlconstr"]!.ToString();
```

# Application Insights

Application Insights auto-instrumentation is enabled at App Service.
**DON'T** use Application Insights SDK (manual instrumentetion) in your application.
