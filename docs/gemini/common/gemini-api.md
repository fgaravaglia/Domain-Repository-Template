---
description: 'Guidelines for building REST APIs with ASP.NET'
applyTo: '**/*.cs, **/*.json'
---

# ASP.NET REST API Development

## Instruction

- Guide users through building their first REST API using ASP.NET Core 9.
- Explain both traditional Web API controllers and the newer Minimal API approach.
- Provide educational context for each implementation decision to help users understand the underlying concepts.
- Emphasize best practices for API design, testing, documentation, and deployment.
- Focus on providing explanations alongside code examples rather than just implementing features.

## API Design Fundamentals

**API Layer Responsibilities:**

- HTTP request/response handling
- Input validation and model binding
- Authentication and authorization
- Response formatting and status codes
- Error handling and exception mapping
- **Keep Controllers Thin:** Controllers are the entry point for HTTP requests. Their job is to:
    1. Parse the incoming request (model binding).
    2. Call the appropriate application or domain service to execute the business logic.
    3. Map the result back to an HTTP response.
- Do not place any business logic inside controllers.

**What API Layer Should NOT Do:**

- Business logic processing
- Direct database access
- Complex data transformations
- Business rule validation (beyond input format)

**Guidelines:**

- Explain REST architectural principles and how they apply to ASP.NET Core APIs.
- Guide users in designing meaningful resource-oriented URLs and appropriate HTTP verb usage.
- Demonstrate the difference between traditional controller-based APIs and Minimal APIs.
- Explain status codes, content negotiation, and response formatting in the context of REST.
- Help users understand when to choose Controllers vs. Minimal APIs based on project requirements.

## Project Setup and Structure

- Guide users through creating a new ASP.NET Core 9 Web API project with the appropriate templates.
- Explain the purpose of each generated file and folder to build understanding of the project structure.
- Demonstrate how to organize code using feature folders or domain-driven design principles.
- Show proper separation of concerns with models, services, and data access layers.
- Explain the Program.cs and configuration system in ASP.NET Core 9 including environment-specific settings.
- add these nuget packages to the project:
  - Microsoft.AspNetCore.Authentication.JwtBearer
  - Microsoft.AspNetCore.Mvc.Versioning
  - Microsoft.AspNetCore.Mvc.Versioning.ApiExplorer
  - Swashbuckle.AspNetCore
  - Serilog.AspNetCore
  - Serilog.Sinks.Console
  - Serilog.Sinks.File
  - Asp.Versioning.Mvc
  - Asp.Versioning.ApiExplorer

## API Project Structure

Architettura Feature-Based: each feature (example: CUstomer, orders, products) is organized as a module self-contained in the API layer.

``` txt
API/
├── Areas/
│   ├── V1/
│       ├── Customers/
│       │   ├── DTOs/
│       │   │   ├── CreateCustomerRequest.cs
│       │   │   ├── UpdateCustomerRequest.cs
│       │   │   └── CustomerResponse.cs
│       │   ├── Validators/
│       │   │   ├── CreateCustomerValidator.cs
│       │   │   └── UpdateCustomerValidator.cs
│       │   ├── Mappings/
│       │   │   └── CustomerMappingProfile.cs
│       │   └── CustomersController.cs
│       ├── Orders/
│       │   ├── DTOs/
│       │   │   ├── PlaceOrderRequest.cs
│       │   │   ├── UpdateOrderRequest.cs
│       │   │   └── OrderResponse.cs
│       │   ├── Validators/
│       │   │   ├── PlaceOrderValidator.cs
│       │   │   └── UpdateOrderValidator.cs
│       │   ├── Mappings/
│       │   │   └── OrderMappingProfile.cs
│       │   └── OrdersController.cs
│       ├── Products/
│           ├── DTOs/
│           │   ├── CreateProductRequest.cs
│           │   └── ProductResponse.cs
│           ├── Validators/
│           │   └── CreateProductValidator.cs
│           ├── Mappings/
│           │   └── ProductMappingProfile.cs
│           └── ProductsController.cs
├── Common/
│   ├── DTOs/
│   │   ├── ApiResponse.cs
│   │   ├── PaginatedResponse.cs
│   │   └── ValidationErrorResponse.cs
│   ├── Middleware/
│   │   ├── ExceptionHandlingMiddleware.cs
│   │   ├── RequestLoggingMiddleware.cs
│   │   └── RateLimitingMiddleware.cs
│   ├── Filters/
│   │   ├── ValidationActionFilter.cs
│   │   └── ModelStateValidationFilter.cs
│   └── Extensions/
│       ├── ServiceCollectionExtensions.cs
│       └── ApplicationBuilderExtensions.cs
├── Configuration/
│   ├── SwaggerConfiguration.cs
│   ├── CorsConfiguration.cs
│   └── ApiVersioningConfiguration.cs
├── Program.cs
└── appsettings.json
```

## Building Controller-Based APIs

- Guide the creation of RESTful controllers with proper resource naming and HTTP verb implementation.
- Explain attribute routing and its advantages over conventional routing.
- Demonstrate model binding, validation, and the role of [ApiController] attribute.
- Show how dependency injection works within controllers.
- Explain action return types (IActionResult, ActionResult<T>, specific return types) and when to use each.
- **HTTP Status Codes:** Use standard codes correctly:
  - `200 OK` for successful GET requests.
  - `201 Created` for successful POST requests that create a resource. Include a `Location` header.
  - `204 NoContent` for successful PUT, PATCH, or DELETE requests.
  - `400 BadRequest` for client-side validation errors.
  - `404 NotFound` when a requested resource does not exist.
- **Routing:** Use attribute-based routing on controllers (`[Route("api/[controller]")]`).
- **Error Handling:** Implement a global exception handler middleware to catch unhandled exceptions and return a standardized `500 Internal Server Error` response.

## Implementing Minimal APIs

- Guide users through implementing the same endpoints using the Minimal API syntax.
- Explain the endpoint routing system and how to organize route groups.
- Demonstrate parameter binding, validation, and dependency injection in Minimal APIs.
- Show how to structure larger Minimal API applications to maintain readability.
- Compare and contrast with controller-based approach to help users understand the differences.

### Data Transfer Objects (DTOs) Principles

- **NEVER expose domain entities directly to the client.**
- Always use Data Transfer Objects (DTOs) for request bodies and response payloads.
- Create specific DTOs for each use case (e.g., `CreateUserRequest`, `UserResponse`).
- Use libraries like AutoMapper for mapping between entities and DTOs, but manual mapping is also acceptable for simple cases.

## Authentication and Authorization

- Guide users through implementing authentication using JWT Bearer tokens.
- Explain OAuth 2.0 and OpenID Connect concepts as they relate to ASP.NET Core.
- Show how to implement role-based and policy-based authorization.
- Demonstrate integration with Microsoft Entra ID (formerly Azure AD).
- Explain how to secure both controller-based and Minimal APIs consistently.

## Validation and Error Handling

- Guide the implementation of model validation using data annotations and FluentValidation.
- Explain the validation pipeline and how to customize validation responses.
- Demonstrate a global exception handling strategy using middleware.
- Show how to create consistent error responses across the API.
- Explain problem details (RFC 7807) implementation for standardized error responses.

## API Versioning and Documentation

- Guide users through implementing and explaining API versioning strategies.
- Demonstrate Swagger/OpenAPI implementation with proper documentation.
- Show how to document endpoints, parameters, responses, and authentication.
- Explain versioning in both controller-based and Minimal APIs.
- Guide users on creating meaningful API documentation that helps consumers.

## Logging and Monitoring

- Guide the implementation of structured logging using Serilog or other providers.
- Explain the logging levels and when to use each.
- Demonstrate integration with Application Insights for telemetry collection.
- Show how to implement custom telemetry and correlation IDs for request tracking.
- Explain how to monitor API performance, errors, and usage patterns.

## Testing REST APIs

- Guide users through creating unit tests for controllers, Minimal API endpoints, and services.
- Explain integration testing approaches for API endpoints.
- Demonstrate how to mock dependencies for effective testing.
- Show how to test authentication and authorization logic.
- Explain test-driven development principles as applied to API development.

## Performance Optimization

- Guide users on implementing caching strategies (in-memory, distributed, response caching).
- Explain asynchronous programming patterns and why they matter for API performance.
- Demonstrate pagination, filtering, and sorting for large data sets.
- Show how to implement compression and other performance optimizations.
- Explain how to measure and benchmark API performance.

## Deployment and DevOps

- Guide users through containerizing their API using .NET's built-in container support (`dotnet publish --os linux --arch x64 -p:PublishProfile=DefaultContainer`).
- Explain the differences between manual Dockerfile creation and .NET's container publishing features.
- Explain CI/CD pipelines for ASP.NET Core applications.
- Demonstrate deployment to Azure App Service, Azure Container Apps, or other hosting options.
- Show how to implement health checks and readiness probes.
- Explain environment-specific configurations for different deployment stages.

## Code Samples and Scaffolded Items

### Base Controller with Common Functionality

```csharp
namespace YourCompany.YourDomain.API.Controllers.Common;

/// <summary>
/// Base controller providing common functionality for all API controllers.
/// Implements standard patterns for error handling, response formatting, and logging.
/// </summary>
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[Produces("application/json")]
[ProducesResponseType(typeof(ValidationErrorResponse), StatusCodes.Status400BadRequest)]
[ProducesResponseType(typeof(ApiErrorResponse), StatusCodes.Status500InternalServerError)]
public abstract class BaseApiController : ControllerBase
{
    protected readonly IMediator Mediator;
    protected readonly IMapper Mapper;
    protected readonly ILogger Logger;

    protected BaseApiController(IMediator mediator, IMapper mapper, ILogger logger)
    {
        Mediator = mediator;
        Mapper = mapper;
        Logger = logger;
    }

    /// <summary>
    /// Creates a success response with data and optional pagination information.
    /// </summary>
    /// <typeparam name="T">The type of data being returned.</typeparam>
    /// <param name="data">The data to include in the response.</param>
    /// <param name="message">Optional success message.</param>
    /// <returns>Formatted API response with success status.</returns>
    protected ActionResult<ApiResponse<T>> SuccessResponse<T>(T data, string? message = null)
    {
        var response = new ApiResponse<T>
        {
            Success = true,
            Data = data,
            Message = message ?? "Operation completed successfully",
            Timestamp = DateTime.UtcNow
        };

        return Ok(response);
    }

    /// <summary>
    /// Creates a paginated success response for collection data.
    /// </summary>
    /// <typeparam name="T">The type of items in the collection.</typeparam>
    /// <param name="data">The collection data.</param>
    /// <param name="pageNumber">Current page number.</param>
    /// <param name="pageSize">Number of items per page.</param>
    /// <param name="totalCount">Total number of items available.</param>
    /// <returns>Formatted paginated API response.</returns>
    protected ActionResult<PaginatedResponse<T>> PaginatedResponse<T>(
        IEnumerable<T> data,
        int pageNumber,
        int pageSize,
        int totalCount)
    {
        var response = new PaginatedResponse<T>
        {
            Success = true,
            Data = data,
            PageNumber = pageNumber,
            PageSize = pageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling((double)totalCount / pageSize),
            HasNextPage = pageNumber * pageSize < totalCount,
            HasPreviousPage = pageNumber > 1,
            Timestamp = DateTime.UtcNow
        };

        return Ok(response);
    }

    /// <summary>
    /// Creates a created response for resource creation operations.
    /// </summary>
    /// <typeparam name="T">The type of created resource.</typeparam>
    /// <param name="data">The created resource data.</param>
    /// <param name="location">The location of the created resource.</param>
    /// <returns>HTTP 201 Created response with location header.</returns>
    protected ActionResult<ApiResponse<T>> CreatedResponse<T>(T data, string location)
    {
        var response = new ApiResponse<T>
        {
            Success = true,
            Data = data,
            Message = "Resource created successfully",
            Timestamp = DateTime.UtcNow
        };

        return Created(location, response);
    }

    /// <summary>
    /// Handles common exceptions and converts them to appropriate HTTP responses.
    /// </summary>
    /// <param name="exception">The exception to handle.</param>
    /// <returns>Appropriate HTTP error response.</returns>
    protected ActionResult HandleException(Exception exception)
    {
        return exception switch
        {
            ValidationException validationEx => BadRequest(new ValidationErrorResponse
            {
                Success = false,
                Message = "Validation failed",
                Errors = validationEx.Errors.ToDictionary(x => x.PropertyName, x => x.ErrorMessage),
                Timestamp = DateTime.UtcNow
            }),

            NotFoundException notFoundEx => NotFound(new ApiErrorResponse
            {
                Success = false,
                Message = notFoundEx.Message,
                ErrorCode = "RESOURCE_NOT_FOUND",
                Timestamp = DateTime.UtcNow
            }),

            UnauthorizedAccessException => Unauthorized(new ApiErrorResponse
            {
                Success = false,
                Message = "Access denied",
                ErrorCode = "UNAUTHORIZED",
                Timestamp = DateTime.UtcNow
            }),

            DomainException domainEx => BadRequest(new ApiErrorResponse
            {
                Success = false,
                Message = domainEx.Message,
                ErrorCode = "BUSINESS_RULE_VIOLATION",
                Timestamp = DateTime.UtcNow
            }),

            _ => StatusCode(StatusCodes.Status500InternalServerError, new ApiErrorResponse
            {
                Success = false,
                Message = "An unexpected error occurred",
                ErrorCode = "INTERNAL_SERVER_ERROR",
                Timestamp = DateTime.UtcNow
            })
        };
    }
}
```

### Common/Extensions

in the folder 'Common/Extensions' you need to generate the classes to manage Dependency Injections and Application builder.
Here you find some examples:

```csharp
namespace Umbrella.Domain.WebApi.Common.Extensions;

/// <summary>
/// Extension methods for setting up presentation-layer services in an <see cref="IServiceCollection"/>.
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Adds presentation-layer services to the service collection.
    /// </summary>
    /// <param name="services">The <see cref="IServiceCollection"/> to add services to.</param>
    /// <returns>The same service collection so that multiple calls can be chained.</returns>
    public static IServiceCollection AddPresentationServices(this IServiceCollection services)
    {
        services.AddControllers();
        services.AddProblemDetails();
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen();

        return services;
    }
}
```

```csharp
using Umbrella.Domain.WebApi.Common.Middleware;

namespace Umbrella.Domain.WebApi.Common.Extensions;

/// <summary>
/// Extension methods for setting up the middleware pipeline.
/// </summary>
public static class ApplicationBuilderExtensions
{
    /// <summary>
    /// Configures the middleware pipeline for the application.
    /// </summary>
    /// <param name="app">The <see cref="WebApplication"/> to configure.</param>
    /// <returns>The same application builder so that multiple calls can be chained.</returns>
    public static WebApplication UsePresentationServices(this WebApplication app)
    {
        // Register the global exception handling middleware first.
        app.UseMiddleware<ExceptionHandlingMiddleware>();

        app.UseSwagger();
        app.UseSwaggerUI();

        app.UseHttpsRedirection();

        app.UseAuthorization();

        app.MapControllers();

        return app;
    }
}

```

### Configuration

here you have samples of classes to add to manage specific configuration of REST Api.

- **SwaggerConfiguration.cs** - Questa classe statica conterrà due metodi di estensione:
  1. AddSwaggerServices: Includerà la configurazione di services.AddSwaggerGen(). Aggiungerò anche la configurazione per il supporto dell'autenticazione JWT (Bearer Token) direttamente nell'interfaccia utente di Swagger, rendendola molto più utile per testare gli endpoint sicuri.
  2. UseSwaggerMiddleware: Includerà la configurazione di app.UseSwagger() e app.UseSwaggerUI(), mantenendo la logica per abilitarlo solo in ambiente di sviluppo.
- **CorsConfiguration.cs** - La classe conterrà due metodi di estensione:
    1. AddCorsServices: Aggiungerà i servizi CORS al container DI. Definirà una policy CORS nominata (es. "DefaultPolicy") che leggerà le origini consentite dal file appsettings.json. Questo la renderà flessibile per diversi ambienti (sviluppo, produzione, etc.).
    2. UseCorsMiddleware: Applicherà la policy CORS definita alla pipeline di middleware dell'applicazione.
- **ApiVersioningConfiguration.cs** - La classe conterrà un metodo di estensione statico AddApiVersioningServices. Questo metodo configurerà il versioning delle API, impostando la versione predefinita e abilitando l'esplorazione delle API versionate per l'integrazione con Swagger.

### Program.cs

THe program.cs file must ve as smallest and Cleanest as possible. Here the example:

```csharp
using Umbrella.Authentication.Application;
using Umbrella.Authentication.Infrastructure;
using Umbrella.Authentication.WebApi.Common.Extensions;

var builder = WebApplication.CreateBuilder(args);

// Add services from all layers to the container.
builder.Services
    .AddApplicationServices()
    .AddInfrastructureServices(builder.Configuration)
    .AddPresentationServices();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UsePresentationServices();

app.Run();
```
