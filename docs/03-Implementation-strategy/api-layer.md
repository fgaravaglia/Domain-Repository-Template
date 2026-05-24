# REST API .NET - Best Practices con Extension Methods

## Struttura Progetto

```
YourApi/
├── Controllers/
│   ├── AdvisoryController.cs
│   └── ErrorController.cs
├── DTOs/                               # Request/Response contracts
├── Extensions/
│   ├── ServiceCollectionExtensions.cs  # Registrazione dipendenze
│   ├── WebApplicationExtensions.cs     # Configurazione middleware
│   └── SwaggerExtensions.cs            # Configurazione Swagger
├── Middleware/                         # Exception handling, Custom logging
├── Program.cs                          # Bootstrap minimo
├── appsettings.json
└── appsettings.Development.json
```

---

## 1. Program.cs - Minimalista

```csharp
using Serilog;
using YourApi.Extensions;

// Bootstrap Serilog PRIMA di tutto
// Perché: cattura anche errori di startup
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/api-.log", rollingInterval: RollingInterval.Day)
    .Enrich.FromLogContext()
    .CreateLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);
    
    // Serilog come logger principale
    builder.Host.UseSerilog();
    
    // Extension methods per pulizia
    builder.Services.AddApiServices(builder.Configuration);
    builder.Services.AddApiSwagger();
    builder.Services.AddApiHealthChecks(builder.Configuration);
    
    var app = builder.Build();
    
    // Configura middleware pipeline
    app.ConfigureApiMiddleware();
    
    Log.Information("API started successfully");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application startup failed");
}
finally
{
    Log.CloseAndFlush();
}
```

---

## 2. ServiceCollectionExtensions.cs - Registrazione Dipendenze

```csharp
using System.Text.Json.Serialization;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace YourApi.Extensions;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registra tutti i servizi core dell'API
    /// </summary>
    public static IServiceCollection AddApiServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Controllers con configurazione JSON
        services.AddControllers()
            .AddJsonOptions(options =>
            {
                // camelCase per proprietà (standard REST)
                options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
                
                // Ignora null nelle response (riduce payload)
                options.JsonSerializerOptions.DefaultIgnoreCondition = 
                    JsonIgnoreCondition.WhenWritingNull;
                
                // Enum come stringhe (leggibile in Swagger/Postman)
                options.JsonSerializerOptions.Converters.Add(
                    new JsonStringEnumConverter());
                
                // Formattazione compatta in produzione
                options.JsonSerializerOptions.WriteIndented = false;
            });
        
        services.AddEndpointsApiExplorer();
        
        // CORS se necessario
        services.AddCors(options =>
        {
            options.AddPolicy("AllowFrontend", builder =>
            {
                builder
                    .WithOrigins(configuration["Cors:AllowedOrigins"]?.Split(',') ?? Array.Empty<string>())
                    .AllowAnyMethod()
                    .AllowAnyHeader()
                    .AllowCredentials();
            });
        });
        
        // Registra i tuoi servizi applicativi
        // Perché: centralizza la DI, facile da testare e mockare
        services.AddScoped<IAdvisoryService, AdvisoryService>();
        services.AddScoped<IAdvisoryRepository, AdvisoryRepository>();
        
        // Database contexts (esempio per Entity Framework)
        // services.AddDbContext<AppDbContext>(options =>
        //     options.UseSqlServer(configuration.GetConnectionString("DefaultConnection")));
        
        return services;
    }
    
    /// <summary>
    /// Configura health checks per monitoraggio infrastruttura
    /// </summary>
    public static IServiceCollection AddApiHealthChecks(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddHealthChecks()
            .AddCheck("self", () => HealthCheckResult.Healthy())
            // Aggiungi check DB quando necessario
            // .AddSqlServer(configuration.GetConnectionString("DefaultConnection"))
            // .AddMongoDb(configuration.GetConnectionString("MongoDB"))
            ;
        
        return services;
    }
}
```

---

## 3. SwaggerExtensions.cs - Configurazione Swagger

```csharp
using System.Reflection;
using Microsoft.OpenApi.Models;

namespace YourApi.Extensions;

public static class SwaggerExtensions
{
    /// <summary>
    /// Configura Swagger con documentazione automatica da XML comments
    /// </summary>
    public static IServiceCollection AddApiSwagger(this IServiceCollection services)
    {
        services.AddSwaggerGen(options =>
        {
            // Metadata API
            options.SwaggerDoc("v1", new OpenApiInfo
            {
                Title = "Sales Solutions API",
                Version = "v1",
                Description = "REST API per DPA - Advisory Forex/Investimenti",
                Contact = new OpenApiContact
                {
                    Name = "Tech Team",
                    Email = "team@unicredit.com"
                }
            });
            
            // Includi commenti XML nello Swagger
            // Perché: genera documentazione automatica dai summary dei controller
            var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
            var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
            
            if (File.Exists(xmlPath))
            {
                options.IncludeXmlComments(xmlPath);
            }
            
            // JWT Bearer in Swagger UI
            // Perché: permette di testare endpoint protetti direttamente da Swagger
            options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
            {
                Description = "JWT Authorization header. Esempio: 'Bearer {token}'",
                Name = "Authorization",
                In = ParameterLocation.Header,
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT"
            });
            
            options.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "Bearer"
                        }
                    },
                    Array.Empty<string>()
                }
            });
            
            // Ordina endpoint per tag (migliora leggibilità)
            options.OrderActionsBy(desc => 
                $"{desc.ActionDescriptor.RouteValues["controller"]}_{desc.HttpMethod}");
        });
        
        return services;
    }
}
```

---

## 4. WebApplicationExtensions.cs - Pipeline Middleware

```csharp
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using HealthChecks.UI.Client;

namespace YourApi.Extensions;

public static class WebApplicationExtensions
{
    /// <summary>
    /// Configura la pipeline middleware dell'API
    /// Ordine critico: exception handler → https → auth → logging → routing
    /// </summary>
    public static WebApplication ConfigureApiMiddleware(this WebApplication app)
    {
        // Exception handler globale
        // Perché: centralizza gestione errori, evita try-catch ripetitivi
        app.UseExceptionHandler("/error");
        
        // Swagger solo in Development
        if (app.Environment.IsDevelopment())
        {
            app.UseSwagger();
            app.UseSwaggerUI(options =>
            {
                options.SwaggerEndpoint("/swagger/v1/swagger.json", "API v1");
                options.RoutePrefix = string.Empty; // Swagger alla root
                options.DisplayRequestDuration(); // Mostra timing request
            });
        }
        
        // HTTPS redirect (disabilita in locale se problematico)
        if (!app.Environment.IsDevelopment())
        {
            app.UseHttpsRedirection();
        }
        
        // CORS (se configurato)
        app.UseCors("AllowFrontend");
        
        // Authentication/Authorization
        app.UseAuthentication();
        app.UseAuthorization();
        
        // Serilog request logging
        // Perché: structured logging di ogni request con timing e status code
        app.UseSerilogRequestLogging(options =>
        {
            options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
            {
                // Aggiungi context custom per troubleshooting
                diagnosticContext.Set("UserId", httpContext.User.Identity?.Name);
                diagnosticContext.Set("ClientIP", httpContext.Connection.RemoteIpAddress);
                diagnosticContext.Set("UserAgent", httpContext.Request.Headers.UserAgent);
            };
            
            // Log solo errori e richieste lente in produzione
            options.GetLevel = (httpContext, elapsed, ex) => ex != null
                ? LogEventLevel.Error
                : elapsed > 1000
                    ? LogEventLevel.Warning
                    : LogEventLevel.Information;
        });
        
        // Health checks endpoints
        // /health/ready: tutti i check (DB, cache, etc.) - usato da load balancer
        app.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = _ => true,
            ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
        });
        
        // /health/live: solo check "self" - usato per pod restart
        app.MapHealthChecks("/health/live", new HealthCheckOptions
        {
            Predicate = check => check.Name == "self"
        });
        
        // Map controllers
        app.MapControllers();
        
        return app;
    }
}
```

---

## 5. Controller Esempio

```csharp
namespace YourApi.Controllers;

/// <summary>
/// Gestione advisory forex
/// </summary>
[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class AdvisoryController : ControllerBase
{
    private readonly IAdvisoryService _service;
    private readonly ILogger<AdvisoryController> _logger;
    
    public AdvisoryController(IAdvisoryService service, ILogger<AdvisoryController> logger)
    {
        _service = service;
        _logger = logger;
    }
    
    /// <summary>
    /// Ottieni tutti gli advisory attivi
    /// </summary>
    /// <returns>Lista advisory</returns>
    [HttpGet]
    [ProducesResponseType(typeof(List<AdvisoryResponse>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll()
    {
        var advisories = await _service.GetAllAsync();
        return Ok(advisories);
    }
    
    /// <summary>
    /// Ottieni advisory per ID
    /// </summary>
    /// <param name="id">ID univoco advisory</param>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(AdvisoryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(Guid id)
    {
        var advisory = await _service.GetByIdAsync(id);
        
        if (advisory == null)
        {
            _logger.LogWarning("Advisory {AdvisoryId} not found", id);
            return NotFound();
        }
        
        return Ok(advisory);
    }
    
    /// <summary>
    /// Crea nuovo advisory
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(AdvisoryResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] CreateAdvisoryRequest request)
    {
        _logger.LogInformation(
            "Creating advisory for client {ClientId}", 
            request.ClientId);
        
        var advisory = await _service.CreateAsync(request);
        
        // 201 Created con Location header (REST standard)
        return CreatedAtAction(
            nameof(GetById),
            new { id = advisory.Id },
            advisory);
    }
    
    /// <summary>
    /// Aggiorna advisory esistente
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateAdvisoryRequest request)
    {
        var success = await _service.UpdateAsync(id, request);
        
        if (!success)
            return NotFound();
        
        // 204 No Content (update senza response body)
        return NoContent();
    }
    
    /// <summary>
    /// Elimina advisory
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id)
    {
        var success = await _service.DeleteAsync(id);
        
        if (!success)
            return NotFound();
        
        return NoContent();
    }
}
```

---

## 6. ErrorController - Global Exception Handler
Ensures that no infrastructure-specific exceptions leak to the client:

```csharp
namespace YourApi.Controllers;

/// <summary>
/// Handler centralizzato per eccezioni non gestite
/// </summary>
[ApiController]
[ApiExplorerSettings(IgnoreApi = true)] // Nasconde da Swagger
public class ErrorController : ControllerBase
{
    private readonly ILogger<ErrorController> _logger;
    
    public ErrorController(ILogger<ErrorController> logger)
    {
        _logger = logger;
    }
    
    /// <summary>
    /// Endpoint per gestione errori globale
    /// Configurato con app.UseExceptionHandler("/error")
    /// </summary>
    [Route("/error")]
    public IActionResult HandleError()
    {
        var context = HttpContext.Features.Get<IExceptionHandlerFeature>();
        var exception = context?.Error;
        
        // Log strutturato con severità
        _logger.LogError(
            exception,
            "Unhandled exception occurred. Path: {Path}",
            HttpContext.Request.Path);
        
        // ProblemDetails RFC 7807 compliant
        var problemDetails = new ProblemDetails
        {
            Status = StatusCodes.Status500InternalServerError,
            Title = "An error occurred processing your request",
            Detail = exception?.Message,
            Instance = HttpContext.Request.Path
        };
        
        // Stack trace solo in Development
        // Perché: in produzione esporre lo stack è un rischio sicurezza
        if (HttpContext.RequestServices
            .GetRequiredService<IWebHostEnvironment>()
            .IsDevelopment())
        {
            problemDetails.Extensions["stackTrace"] = exception?.StackTrace;
            problemDetails.Extensions["exceptionType"] = exception?.GetType().Name;
        }
        
        return StatusCode(
            StatusCodes.Status500InternalServerError,
            problemDetails);
    }
}
```

---

## 7. appsettings.json - Configurazione Serilog

```json
{
  "Serilog": {
    "Using": ["Serilog.Sinks.Console", "Serilog.Sinks.File"],
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "Microsoft.AspNetCore": "Warning",
        "System": "Warning"
      }
    },
    "WriteTo": [
      {
        "Name": "Console",
        "Args": {
          "outputTemplate": "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj} {Properties:j}{NewLine}{Exception}"
        }
      },
      {
        "Name": "File",
        "Args": {
          "path": "logs/api-.log",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 30,
          "outputTemplate": "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj} {Properties:j}{NewLine}{Exception}"
        }
      }
    ],
    "Enrich": ["FromLogContext", "WithMachineName", "WithThreadId"]
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=.;Database=YourDb;Trusted_Connection=True;"
  },
  "Cors": {
    "AllowedOrigins": "http://localhost:4200,https://yourfrontend.com"
  }
}
```

---

## 8. .csproj - Configurazione Progetto

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    
    <!-- Genera XML per Swagger -->
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    
    <!-- Ignora warning per metodi pubblici senza XML comments -->
    <NoWarn>$(NoWarn);1591</NoWarn>
  </PropertyGroup>

  <ItemGroup>
    <!-- ASP.NET Core packages -->
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="8.0.0" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Versioning" Version="5.1.0" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Versioning.ApiExplorer" Version="5.1.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
    
    <!-- Validation and Mapping -->
    <PackageReference Include="FluentValidation.AspNetCore" Version="11.3.0" />
    <PackageReference Include="AutoMapper.Extensions.Microsoft.DependencyInjection" Version="12.0.1" />
    
    <!-- Logging and Monitoring -->
    <PackageReference Include="Serilog.AspNetCore" Version="8.0.0" />
    <PackageReference Include="Serilog.Sinks.Console" Version="5.0.0" />
    <PackageReference Include="Serilog.Sinks.File" Version="5.0.0" />
    
    <!-- Security and Rate Limiting -->
    <PackageReference Include="AspNetCoreRateLimit" Version="5.0.0" />
    <PackageReference Include="Microsoft.AspNetCore.DataProtection" Version="8.0.0" />
  </ItemGroup>
</Project>
```

---

## Action Points Immediati

1. **Crea le 3 extension classes**: `ServiceCollectionExtensions`, `SwaggerExtensions`, `WebApplicationExtensions`. Program.cs diventa 20 righe.

2. **Abilita XML Documentation**: `<GenerateDocumentationFile>true</GenerateDocumentationFile>` nel .csproj. Swagger auto-documentato dai commenti.

3. **Implementa ErrorController**: Gestione centralizzata eccezioni. Elimini try-catch in ogni action, log strutturato automatico.

4. **Health checks immediati**: `/health/ready` e `/health/live`. Essenziali per load balancer GCP/Azure.

5. **Structured logging day 1**: Serilog configurato in `appsettings.json`. Query sui log banali quando debuggi Oracle/MongoDB.

---

## Anti-Pattern da Evitare

- **Program.cs di 200 righe**: Tutto inline senza extension methods. Illeggibile e non testabile.
- **Magic strings**: Connection string hardcoded. Usa `IConfiguration` e appsettings.
- **Log non strutturati**: `$"Creating {id}"`. Usa properties: `"Creating {AdvisoryId}", id`.
- **Exception swallowing**: `catch (Exception) { return BadRequest(); }` senza log. Usa global handler.
- **Swagger senza XML**: Documentazione manuale. I commenti triple-slash generano tutto.
