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

## Domain Layer Implementation Examples

### Base Entity

```csharp
namespace YourCompany.YourDomain.Domain.Common;

/// <summary>
/// Base class for all domain entities with strongly-typed identifiers.
/// </summary>
/// <typeparam name="TId">The type of the entity identifier.</typeparam>
public abstract class Entity<TId> : IEquatable<Entity<TId>>
    where TId : notnull
{
    private readonly List<IDomainEvent> _domainEvents = new();

    /// <summary>
    /// Gets the unique identifier for this entity.
    /// </summary>
    public TId Id { get; protected set; } = default!;

    /// <summary>
    /// Gets the domain events raised by this entity.
    /// </summary>
    public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    /// <summary>
    /// Adds a domain event to be dispatched when the entity is persisted.
    /// </summary>
    /// <param name="domainEvent">The domain event to add.</param>
    protected void AddDomainEvent(IDomainEvent domainEvent)
    {
        _domainEvents.Add(domainEvent);
    }

    /// <summary>
    /// Clears all pending domain events.
    /// </summary>
    public void ClearDomainEvents()
    {
        _domainEvents.Clear();
    }

    public bool Equals(Entity<TId>? other)
    {
        return other is not null && Id.Equals(other.Id);
    }

    public override bool Equals(object? obj)
    {
        return obj is Entity<TId> entity && Equals(entity);
    }

    public override int GetHashCode()
    {
        return Id.GetHashCode();
    }
}
```

#### Value Object Example

```csharp
namespace YourCompany.YourDomain.Domain.ValueObjects;

/// <summary>
/// Represents a monetary value with currency information.
/// </summary>
public sealed class Money : ValueObject
{
    /// <summary>
    /// Gets the monetary amount.
    /// </summary>
    public decimal Amount { get; }

    /// <summary>
    /// Gets the currency code (e.g., "USD", "EUR").
    /// </summary>
    public string Currency { get; }

    /// <summary>
    /// Initializes a new instance of the <see cref="Money"/> class.
    /// </summary>
    /// <param name="amount">The monetary amount.</param>
    /// <param name="currency">The currency code.</param>
    /// <exception cref="ArgumentException">Thrown when currency is null or empty.</exception>
    public Money(decimal amount, string currency)
    {
        if (string.IsNullOrWhiteSpace(currency))
            throw new ArgumentException("Currency cannot be null or empty.", nameof(currency));

        Amount = amount;
        Currency = currency.ToUpperInvariant();
    }

    /// <summary>
    /// Adds two money values of the same currency.
    /// </summary>
    /// <param name="left">The first money value.</param>
    /// <param name="right">The second money value.</param>
    /// <returns>A new <see cref="Money"/> instance with the sum.</returns>
    /// <exception cref="InvalidOperationException">Thrown when currencies don't match.</exception>
    public static Money operator +(Money left, Money right)
    {
        if (left.Currency != right.Currency)
            throw new InvalidOperationException("Cannot add money with different currencies.");

        return new Money(left.Amount + right.Amount, left.Currency);
    }

    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Amount;
        yield return Currency;
    }

    public override string ToString() => $"{Amount:C} {Currency}";
}
```
