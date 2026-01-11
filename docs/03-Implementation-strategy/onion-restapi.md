# REST API Implementation Guide

This comprehensive guide demonstrates how to implement RESTful APIs following Onion Architecture principles using ASP.NET Core. The focus is on creating a clean separation between presentation concerns (HTTP/REST) and business logic while maintaining proper dependency flow and testability.

## Strategy: Architectural Rules

```txt
┌─────────────────────────────────────────────┐
│              Web API (Presentation)         │ ← Controllers, DTOs, Middleware
│  ┌────────────────────────────────────────┐ │
│  │           Infrastructure               │ ← Repositories, External Services
│  │  ┌───────────────────────────────────┐ │ │
│  │  │           Application             │ ← Use Cases, Commands/Queries
│  │  │  ┌──────────────────────────────┐ │ │ │
│  │  │  │           Domain             │ ← Business Logic, Entities
│  │  │  └──────────────────────────────┘ │ │ │
│  │  └───────────────────────────────────┘ │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘

API Dependencies: Presentation → Application → Domain
```

Architetural rules:

- Result Pattern Mapping: Automatic conversion of Result<T> from the Application layer into appropriate HTTP responses (200, 400, 404, etc.).
- Global Exception Handling: Centralized middleware to catch unexpected errors and return ProblemDetails compliant with RFC 7807.
- Documentation: Mandatory OpenAPI (Swagger) with XML comments for every endpoint.
- No Logic in Program.cs: Use extension methods (AddApplication, AddInfrastructure) to keep the bootstrapper clean.
- DTO Immutability: Use record for all API input/output models located in the Contracts folder.
- Versioning: Use Asp.Versioning.Mvc package to handle API versions via URL.
- Security: Always enable CORS, HSTS, and define rate-limiting policies.

## 2. Project Structure for REST API

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <DocumentationFile>bin\$(Configuration)\$(TargetFramework)\$(AssemblyName).xml</DocumentationFile>
  </PropertyGroup>

  <ItemGroup>
    <!-- Project References -->
    <ProjectReference Include="..\YourCompany.YourDomain.Application\YourCompany.YourDomain.Application.csproj" />
    <ProjectReference Include="..\YourCompany.YourDomain.Infrastructure\YourCompany.YourDomain.Infrastructure.csproj" />
  </ItemGroup>

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

## 3. Folder Structure

```txt
API/
├── Controllers/        # Standard API Controllers (inheriting from ApiControllerBase)
├── Middleware/         # Exception handling, Custom logging
├── Extensions/         # Service registration (Swagger, Auth)
├── DTOs/               # Request/Response contracts
└── Program.cs          # Entry point and container composition
```

## 4. Examples

### Controller

```csharp
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
public abstract class ApiControllerBase : ControllerBase
{
    protected IActionResult HandleResult<T>(Result<T> result)
    {
        if (result.IsSuccess)
            return result.Value is null ? Ok() : Ok(result.Value);

        return result.Error.Type switch
        {
            ErrorType.NotFound => NotFound(result.Error),
            ErrorType.Validation => BadRequest(result.Error),
            ErrorType.Conflict => Conflict(result.Error),
            _ => StatusCode(500, result.Error)
        };
    }
}

[ApiVersion("1.0")]
[Tags("Orders")]
public class OrdersController(IMediator mediator) : ApiControllerBase
{
    [HttpPost]
    [ProducesResponseType(typeof(OrderResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateOrder(CreateOrderRequest request, CancellationToken ct)
    {
        var command = new CreateOrderCommand(request.CustomerId, request.Items);
        var result = await mediator.Send(command, ct);

        if (result.IsSuccess)
        {
            return CreatedAtAction(nameof(GetOrder), new { id = result.Value.Id }, result.Value);
        }

        return HandleResult(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetOrder(Guid id, CancellationToken ct)
    {
        var query = new GetOrderQuery(id);
        return HandleResult(await mediator.Send(query, ct));
    }
}
```

### Error Handling
Ensures that no infrastructure-specific exceptions leak to the client:

```csharp
namespace YourCompany.YourDomain.API.Infrastructure.Middleware;

public class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception occurred: {Message}", ex.Message);

            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Status = StatusCodes.Status500InternalServerError,
                Title = "Server Error",
                Detail = "An unexpected error occurred on our end."
            });
        }
    }
}
```
