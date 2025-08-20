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

## API Project Structure

Architettura Feature-Based: each feature (example: CUstomer, orders, products) is organized as a module self-contained in the API layer.

``` txt
API/
├── Controllers/
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
