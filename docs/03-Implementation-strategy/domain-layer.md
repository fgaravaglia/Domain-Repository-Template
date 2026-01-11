# Domain Layer Project Setup

You are operating within the Domain layer. This is the heart of the application and contains the core business logic.

## Core Domain Rules

1. **Purity**:
    * This layer MUST NOT contain references to external technologies like databases, APIs, or infrastructure libraries.
2. **Entities and Aggregates**:
    * Entities must have a clear identity and encapsulate business logic through methods. Avoid anemic domain models (classes with only properties and no behavior).
    * Identify and use Aggregates to maintain transactional consistency.
3. **Value Objects**: Use Value Objects to model descriptive and immutable concepts (e.g., `EmailAddress`, `Money`).
4. **Interfaces**:
    * Define interfaces for repositories (e.g., `IUserRepository`) and domain services here. The concrete implementations will reside in the infrastructure layer.
    * the only public objects are interfaces, Extensions classes for manage dependency Injections, Data Transfer objects (DTO)
    * The Domain Service Interface must to use DTO to define input and outputs

## Domain Facade

Each domain must have a public interface called I{Domain Name}Service, that exposed all public capabilities outside the domain. this interface is then implmemented by an internal class named {Domain Name}Service.
This domain service has some spcific constraints:

* accepts in the constructor the Repository interfaces defined in this domain
* accepts in the constructor the Microsoft.Extensions.Logging.ILogger
* begin each public method with a scope for logging, containig the mening info for the context
* reduce Try&catch syntax to he minimum, demaing the exception managemnt to the caller.

## Strict Constraints

* **FORBIDDEN**: Do not add `using` directives for `Microsoft.EntityFrameworkCore`, `System.Data`, `Newtonsoft.Json`, or any other infrastructure library.
* **FORBIDDEN**: Do not add project references to the `Infrastructure` or `WebApi` layers.
* **FORBIDDEN**: do not use domain objects to define methods of Domain Service Interface.
* **REQUIRED**: The logic in this layer must be testable in isolation.
* **DEPENDENCIES**:
  * Add reference to Microsoft.Extensions.Logging
  * Add reference to Microsoft.Extensions.DependencyInjection

## Project Creation

**Command Line:**

```bash
# Create Domain project
dotnet new classlib -n YourCompany.YourDomain.Domain
cd YourCompany.YourDomain.Domain

# Configure project properties
dotnet add package Microsoft.Extensions.DependencyInjection.Abstractions
```

## Domain Project Configuration (.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
  </PropertyGroup>

  <ItemGroup>
    <!-- Minimal dependencies - only abstractions allowed -->
    <PackageReference Include="Microsoft.Extensions.DependencyInjection.Abstractions" Version="8.0.0" />
  </ItemGroup>

</Project>
```

* ✅ No project references allowed
* ✅ Only abstraction packages (Microsoft.Extensions.DependencyInjection.Abstractions)
* ❌ No Entity Framework references
* ❌ No ASP.NET Core references

## Domain Layer Structure

```txt
Domain/
├── Entities/
│   ├── Customer.cs
│   ├── Order.cs
│   └── OrderItem.cs
├── ValueObjects/
│   ├── CustomerId.cs
│   ├── Money.cs
│   └── Address.cs
├── Aggregates/
│   └── OrderAggregate/
│       ├── Order.cs
│       ├── OrderItem.cs
│       └── IOrderRepository.cs
├── DomainServices/
│   ├── IPricingService.cs
│   └── OrderDomainService.cs
├── DomainEvents/
│   ├── OrderCreatedEvent.cs
│   └── OrderCancelledEvent.cs
├── Exceptions/
│   ├── DomainException.cs
│   └── OrderException.cs
├── Enums/
│   ├── OrderStatus.cs
│   └── PaymentMethod.cs
├── Interfaces/
│   ├── IRepository.cs
│   └── IDomainEventDispatcher.cs
└── Specifications/
    ├── CustomerEligibilitySpec.cs
    └── OrderValidationSpec.cs
```
