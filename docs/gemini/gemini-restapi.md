# REST API Implementation Guide

This comprehensive guide demonstrates how to implement RESTful APIs following Onion Architecture principles using ASP.NET Core. The focus is on creating a clean separation between presentation concerns (HTTP/REST) and business logic while maintaining proper dependency flow and testability.

## 1. Presentation Layer Architecture

### API Layer Positioning in Onion Architecture

```txt
┌─────────────────────────────────────────────┐
│              Web API (Presentation)         │ ← Controllers, DTOs, Middleware
│  ┌─────────────────────────────────────────┐ │
│  │           Infrastructure               │ │ ← Repositories, External Services
│  │  ┌─────────────────────────────────────┐ │ │
│  │  │           Application              │ │ │ ← Use Cases, Commands/Queries
│  │  │  ┌─────────────────────────────────┐ │ │ │
│  │  │  │           Domain               │ │ │ │ ← Business Logic, Entities
│  │  │  └─────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘

API Dependencies: Presentation → Application → Domain
```

### Core Principles for REST API Design

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

### Data Transfer Objects (DTOs) Principles

- **NEVER expose domain entities directly to the client.**
- Always use Data Transfer Objects (DTOs) for request bodies and response payloads.
- Create specific DTOs for each use case (e.g., `CreateUserRequest`, `UserResponse`).
- Use libraries like AutoMapper for mapping between entities and DTOs, but manual mapping is also acceptable for simple cases.

### API Conventions

- **Return Types:** Use `ActionResult<T>` as the return type for controller actions to allow for standard HTTP status code responses.
- **HTTP Status Codes:** Use standard codes correctly:
  - `200 OK` for successful GET requests.
  - `201 Created` for successful POST requests that create a resource. Include a `Location` header.
  - `204 NoContent` for successful PUT, PATCH, or DELETE requests.
  - `400 BadRequest` for client-side validation errors.
  - `404 NotFound` when a requested resource does not exist.
- **Routing:** Use attribute-based routing on controllers (`[Route("api/[controller]")]`).
- **Error Handling:** Implement a global exception handler middleware to catch unhandled exceptions and return a standardized `500 Internal Server Error` response.

## 2. Project Structure for REST API

### API Project Setup

```bash
# Create Web API project
dotnet new webapi -n YourCompany.YourDomain.API
cd YourCompany.YourDomain.API

# Add necessary references
dotnet add reference ../YourCompany.YourDomain.Application/YourCompany.YourDomain.Application.csproj
dotnet add reference ../YourCompany.YourDomain.Infrastructure/YourCompany.YourDomain.Infrastructure.csproj
```

### API Project Structure

``` txt
API/
├── Controllers/
│   ├── V1/
│   │   ├── CustomersController.cs
│   │   ├── OrdersController.cs
│   │   └── ProductsController.cs
│   └── V2/
│       └── CustomersV2Controller.cs
├── DTOs/
│   ├── Requests/
│   │   ├── CreateCustomerRequest.cs
│   │   ├── UpdateOrderRequest.cs
│   │   └── PlaceOrderRequest.cs
│   ├── Responses/
│   │   ├── CustomerResponse.cs
│   │   ├── OrderResponse.cs
│   │   └── ApiResponse.cs
│   └── Common/
│       ├── PaginatedResponse.cs
│       └── ValidationErrorResponse.cs
├── Middleware/
│   ├── ExceptionHandlingMiddleware.cs
│   ├── RequestLoggingMiddleware.cs
│   └── RateLimitingMiddleware.cs
├── Filters/
│   ├── ValidationFilter.cs
│   ├── AuthorizationFilter.cs
│   └── ModelStateValidationFilter.cs
├── Validators/
│   ├── CreateCustomerRequestValidator.cs
│   └── PlaceOrderRequestValidator.cs
├── Mappings/
│   ├── CustomerMappingProfile.cs
│   └── OrderMappingProfile.cs
├── Extensions/
│   ├── ServiceCollectionExtensions.cs
│   └── ApplicationBuilderExtensions.cs
├── Configuration/
│   ├── SwaggerConfiguration.cs
│   └── CorsConfiguration.cs
├── Program.cs
└── appsettings.json
```

### API Project Configuration (.csproj)

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

## 3. Controller Implementation Patterns

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

## 4. DTO Design Patterns

### Request DTOs with Validation

```csharp
namespace YourCompany.YourDomain.API.DTOs.Requests;

/// <summary>
/// Request model for creating a new customer.
/// Contains all required and optional information for customer registration.
/// </summary>
public class CreateCustomerRequest
{
    /// <summary>
    /// The customer's full name.
    /// </summary>
    /// <example>John Smith</example>
    [Required(ErrorMessage = "Name is required")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Name must be between 2 and 100 characters")]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// The customer's email address (must be unique).
    /// </summary>
    /// <example>john.smith@example.com</example>
    [Required(ErrorMessage = "Email is required")]
    [EmailAddress(ErrorMessage = "Invalid email format")]
    [StringLength(255, ErrorMessage = "Email cannot exceed 255 characters")]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// The customer's phone number.
    /// </summary>
    /// <example>+1-555-123-4567</example>
    [Phone(ErrorMessage = "Invalid phone number format")]
    [StringLength(20, ErrorMessage = "Phone number cannot exceed 20 characters")]
    public string? PhoneNumber { get; set; }

    /// <summary>
    /// The customer's date of birth (must be at least 18 years old).
    /// </summary>
    /// <example>1990-05-15</example>
    [Required(ErrorMessage = "Date of birth is required")]
    [DataType(DataType.Date)]
    public DateTime DateOfBirth { get; set; }

    /// <summary>
    /// The customer's address information.
    /// </summary>
    [Required(ErrorMessage = "Address is required")]
    [ValidateNever] // Will be validated by nested validator
    public CreateAddressRequest Address { get; set; } = new();

    /// <summary>
    /// The customer's preferred method of contact.
    /// </summary>
    /// <example>Email</example>
    [Required(ErrorMessage = "Preferred contact method is required")]
    [EnumDataType(typeof(ContactMethod), ErrorMessage = "Invalid contact method")]
    public ContactMethod PreferredContactMethod { get; set; } = ContactMethod.Email;
}
```

### Response DTOs with Documentation

```csharp
namespace YourCompany.YourDomain.API.DTOs.Responses;

/// <summary>
/// Response model containing customer information.
/// </summary>
public class CustomerResponse
{
    /// <summary>
    /// The unique identifier for the customer.
    /// </summary>
    /// <example>550e8400-e29b-41d4-a716-446655440000</example>
    public Guid Id { get; set; }

    /// <summary>
    /// The customer's full name.
    /// </summary>
    /// <example>John Smith</example>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// The customer's email address.
    /// </summary>
    /// <example>john.smith@example.com</example>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// The customer's phone number.
    /// </summary>
    /// <example>+1-555-123-4567</example>
    public string? PhoneNumber { get; set; }

    /// <summary>
    /// The customer's current status.
    /// </summary>
    /// <example>Active</example>
    public CustomerStatus Status { get; set; }

    /// <summary>
    /// The customer's preferred contact method.
    /// </summary>
    /// <example>Email</example>
    public ContactMethod PreferredContactMethod { get; set; }

    /// <summary>
    /// The date when the customer account was created.
    /// </summary>
    /// <example>2023-01-15T10:30:00Z</example>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// The date when the customer information was last updated.
    /// </summary>
    /// <example>2023-06-20T14:45:00Z</example>
    public DateTime? UpdatedAt { get; set; }
}

