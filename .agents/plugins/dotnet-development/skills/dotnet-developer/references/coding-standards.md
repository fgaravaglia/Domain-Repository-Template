# .NET Coding Standards

Primary reference: Microsoft C# Coding Conventions. Where this file is silent, follow Microsoft's.

## Contents

1. Platform and project setup
2. Naming
3. Formatting and layout
4. Nullability
5. Dependency injection and services
6. Async
7. Configuration
8. Error handling
9. Data access (EF Core)
10. HTTP clients and resilience
11. Logging and monitoring
12. Performance
13. Code quality
14. Patterns
15. Containers and delivery

---

## 1. Platform and project setup

- Target `net10.0` (LTS, supported to Nov 2028). `.NET 8` and `.NET 9` reach end of support on **10 Nov 2026**: only for existing code, with a migration ticket.
- Use the default C# version of the target framework (C# 14 for net10.0). Do not hard-code `LangVersion` unless there is a reason, so the language upgrades with the SDK.
- Use `assets/Directory.Build.props` so every project gets the same settings: nullable, implicit usings, warnings as errors, NuGet audit, XML docs.
- Use `assets/.editorconfig` so the IDE and the build enforce naming and formatting (`EnforceCodeStyleInBuild`).
- Prefer Central Package Management (`Directory.Packages.props`) in multi-project solutions: one version per package, one place to bump.
- Use implicit usings in production code. Test projects add a `GlobalUsings.cs` (see nunit reference).

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
```

## 2. Naming

| Element | Rule | Example |
| --- | --- | --- |
| Types, methods, properties, events, public members | PascalCase | `CustomerService`, `GetById` |
| Private fields | `_camelCase` | `_customerRepository` |
| Locals, parameters | camelCase | `customerId` |
| Interfaces | `I` prefix | `IUserService` |
| Constants | PascalCase | `MaxRetryCount` |
| Async methods | `Async` suffix | `GetByIdAsync` |
| Generic type parameters | `T` or `TName` | `TEntity` |
| Test projects | `[ProjectName].Tests` | `Contoso.Customers.Tests` |

Use names that reflect domain concepts (`Invoice`, `SettlementDate`), not technical ones (`Manager`, `Helper`, `Data`).

```csharp
// CORRECT
public class CustomerService
{
    #region Fields

    private readonly ICustomerRepository _customerRepository;
    private readonly ILogger<CustomerService> _logger;

    #endregion

    public CustomerService(ICustomerRepository customerRepository, ILogger<CustomerService> logger)
    {
        ArgumentNullException.ThrowIfNull(customerRepository);
        ArgumentNullException.ThrowIfNull(logger);

        _customerRepository = customerRepository;
        _logger = logger;
    }
}

// INCORRECT - missing underscore, no Fields region, no null guards
public class CustomerService
{
    private readonly ICustomerRepository customerRepository;
}
```

## 3. Formatting and layout

- File-scoped namespaces. Single-line `using` directives, outside the namespace.
- Allman style: a newline before the opening brace of every block (`if`, `for`, `while`, `foreach`, `using`, `try`, methods, types).
- The final `return` of a method sits on its own line (no one-line `if (x) return y;` chains that hide the exit).
- All private fields in a `#region Fields` at the top of the class.
- One public type per file, file named after the type.
- Prefer pattern matching and switch expressions over `if/else` chains and `is`+cast.
- Use `nameof(x)` instead of `"x"`.
- Prefer collection expressions (`[]`), `required` members and records for immutable data.
- Keep methods short and cohesive; if a method needs a comment block to explain its sections, extract methods.

```csharp
public decimal GetDiscountRate(LoyaltyTier tier)
{
    // Why a switch expression: the compiler flags unhandled enum members, so adding a tier cannot silently get 0%.
    var rate = tier switch
    {
        LoyaltyTier.Bronze => 0.02m,
        LoyaltyTier.Silver => 0.05m,
        LoyaltyTier.Gold => 0.08m,
        LoyaltyTier.Platinum => 0.15m,
        _ => throw new ArgumentOutOfRangeException(nameof(tier), tier, "Unknown loyalty tier."),
    };

    return rate;
}
```

## 4. Nullability

- Everything is non-nullable by default. Mark `T?` only when null is a legitimate value in the domain.
- Check for null **at entry points** (public methods, constructors, API boundaries) and then trust the annotations inside.
- `is null` / `is not null`, never `== null` / `!= null` (operator overloads can lie; `is` cannot).
- Do not add null checks the compiler already guarantees. Redundant checks hide real contract violations.
- Do not silence warnings with `!` unless you can write a one-line comment on why it is safe (EF navigation properties and test fields initialised in `[SetUp]` are the typical cases).

## 5. Dependency injection and services

- Constructor injection only. No service locator (`IServiceProvider.GetService` in business code), no static state.
- Guard every injected dependency with `ArgumentNullException.ThrowIfNull`.
- Register with the right lifetime: Singleton (stateless, thread-safe), Scoped (per request, `DbContext`), Transient (lightweight, stateless). A Singleton must never capture a Scoped service.
- Every service has an interface when it crosses a layer boundary or needs substituting in tests.
- Group registrations in extension methods per layer: `services.AddCustomersApplication()`, `services.AddCustomersInfrastructure(configuration)`.
- Make time and randomness injectable: `TimeProvider` instead of `DateTime.UtcNow`, so tests can control them.
- Mark classes `sealed` by default; unseal only when inheritance is designed.

## 6. Async

- All I/O (database, HTTP, file, messaging) is async. No sync-over-async (`.Result`, `.Wait()`, `.GetAwaiter().GetResult()`).
- Return `Task` or `Task<T>`; `ValueTask` only for measured hot paths. Never `async void` (except event handlers).
- Accept a `CancellationToken` as the last parameter and pass it down to every awaited call.
- `ConfigureAwait(false)`: use it in **library code** (packages and shared libraries). In ASP.NET Core application code there is no synchronization context, so it adds noise without benefit.
- Do not wrap a method in `async/await` if it only returns another task - return the task directly (but keep `async` when you have a `using` or `try/catch` around it).
- Handle exceptions where you can act on them; let the rest bubble to the global handler.

## 7. Configuration

- Strongly-typed options classes bound with the Options pattern, validated at startup:

```csharp
public sealed class PaymentGatewayOptions
{
    public const string SectionName = "PaymentGateway";

    [Required, Url]
    public required string BaseUrl { get; init; }

    [Range(1, 120)]
    public int TimeoutSeconds { get; init; } = 30;
}

builder.Services
    .AddOptions<PaymentGatewayOptions>()
    .BindConfiguration(PaymentGatewayOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart(); // Why: fail at boot, not on the first customer request.
```

- `appsettings.json` for defaults, `appsettings.{Environment}.json` for overrides, environment variables / secret store for secrets. **Never commit secrets** (see security reference).

## 8. Error handling

- Handle edge cases explicitly and fail with specific exceptions: `ArgumentException` family for caller errors, domain exceptions for business-rule violations, never `throw new Exception(...)`.
- Do not use exceptions for expected control flow in hot paths; use `TryXxx` patterns or a result type where failure is a normal outcome.
- Do not swallow exceptions. If you catch, either handle, enrich-and-rethrow (`throw;`, never `throw ex;`), or log-and-continue with a reason in a comment.
- At the HTTP boundary, translate exceptions into RFC 9457 problem details (`AddProblemDetails()` + an `IExceptionHandler`). Never leak stack traces or internal messages.
- Methods that "return null if the input is invalid" are a smell; throw, or return an explicit result.

## 9. Data access (EF Core)

- Use EF Core. Choose the provider per environment consciously (SQL Server in production; SQLite or Testcontainers for integration tests; avoid the in-memory provider for behavior tests, it does not behave like a relational database).
- The `DbContext` already is a unit of work and the `DbSet` already is a repository. Add a repository abstraction only for aggregate roots, to keep the domain free of EF types - not one repository per table.
- Read-only queries: `AsNoTracking()`. Project to DTOs with `Select` instead of loading entities you will not mutate.
- Always paginate list endpoints; always bound result sizes. Sorting and filtering only on indexed columns.
- Avoid N+1: use `Include` / split queries consciously, verify with logs on a realistic data set.
- Schema changes via migrations (reviewed like code); seed data in a dedicated, idempotent step.
- Parameterized queries only. With raw SQL use `FromSql` (interpolated, parameterized) - never string concatenation.

## 10. HTTP clients and resilience

- Always `IHttpClientFactory` (typed or named clients). Never `new HttpClient()` per call.
- Add timeouts and resilience (retry with jitter, circuit breaker) via `Microsoft.Extensions.Http.Resilience`; retries only on idempotent operations.
- Propagate the correlation id on outgoing calls.

## 11. Logging and monitoring

- `Microsoft.Extensions.Logging` with message templates: `_logger.LogInformation("Customer {CustomerId} registered", id)` - never `$"..."`.
- Use the right level: Trace/Debug (diagnostics, off in prod), Information (business events), Warning (recoverable anomaly), Error (operation failed), Critical (service in danger).
- Use scopes for context (`BeginScope` with correlation id / tenant), and `LoggerMessage` source generators on hot paths.
- Never log secrets, tokens, full card/IBAN numbers or unnecessary personal data.
- Telemetry: Application Insights or OpenTelemetry; custom metrics for business KPIs; a correlation id on every request, returned in the response headers.
- Expose health checks: liveness (process is up) and readiness (dependencies reachable) as separate endpoints.

## 12. Performance

- Measure before optimizing (BenchmarkDotNet for micro, load tests for services).
- Caching: `IMemoryCache` for single instance, `IDistributedCache` / `HybridCache` for multi-instance; define expiry and invalidation up front.
- Pagination, filtering, sorting server-side. Response compression where it pays.
- Avoid allocations in hot paths (`Span<T>`, `ArrayPool`) only when a profiler says so.

## 13. Code quality

- SOLID, but pragmatically: no interface for a class with one implementation that never crosses a boundary.
- No duplication through base classes and utilities - but prefer composition over inheritance.
- Methods focused and cohesive; classes small; meaningful domain names.
- Implement `IDisposable` / `IAsyncDisposable` correctly for owned resources; prefer `using` declarations.
- No commented-out code. TODOs carry a ticket reference: `// TODO(PROJ-123): ...`.
- Library or external dependency usage: state the purpose in a comment where it is not obvious.
- When reviewing: make only high-confidence suggestions.

## 14. Patterns

- Interfaces with clear, small contracts (interface segregation), prefixed `I`.
- Factory pattern for complex object creation (static factory methods on aggregates, factories for families of objects).
- Command handler pattern with a generic base (`CommandHandler<TOptions>`) where the project uses it.
- **Primary constructors**: allowed for records, DTOs and trivial types. Not for services with injected dependencies, because they cannot carry the null guards and the `#region Fields` layout required above, and captured parameters are mutable. (Decision recorded in `standards-decisions.md`.)

## 15. Containers and delivery

- Containerize with the SDK: `dotnet publish --os linux --arch x64 -p:PublishProfile=DefaultContainer` (SDK container support; check the docs for your SDK version, newer SDKs also expose the `PublishContainer` target). Use a hand-written Dockerfile only for needs the SDK cannot cover.
- Run as non-root, read-only filesystem where possible, no secrets baked into the image.
- CI pipeline minimum: restore -> build (warnings as errors) -> format check -> test with coverage -> vulnerable/deprecated package scan -> publish artifact.
- Environment-specific config via environment variables / config provider, never per-environment builds.
