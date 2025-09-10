# General Project Rules

## Overview

This document establishes the foundational principles and coding standards for the project, ensuring consistency, maintainability, and adherence to industry best practices.

## 1. Architecture Principles

The project strictly follows **Onion Architecture** patterns with the core principle being the **Dependency Rule**.
**[Onion Architecture Overview](./onion-architecture.md)** - Rules and best practices about Onion Architecture

## 2. Domain layer

**[Domain Layer Guidelines](./domain-layer.md)** - Rules and best practices to write a domain component

## 3. Application layer

**[Application Layer Guidelines](./application-layer.md)** - Rules and best practices to write an application component

## 4. Infrastructure layer

**[Infrastructure Layer Guidelines](./infrastructure-layer.md)** - Rules and best practices to write an infrastructure component

## 5. Project Validation and Best Practices

### Dependency Validation Rules

**Domain Project:**

- ✅ No project references allowed
- ✅ Only abstraction packages (Microsoft.Extensions.DependencyInjection.Abstractions)
- ❌ No Entity Framework references
- ❌ No ASP.NET Core references

**Application Project:**

- ✅ Reference to Domain project only
- ✅ Application-specific packages (MediatR, FluentValidation, AutoMapper)
- ❌ No Infrastructure project reference
- ❌ No database-specific packages

**Infrastructure Project:**

- ✅ References to both Domain and Application projects
- ✅ External service packages
- ✅ Database and caching packages

### Architecture Testing

```csharp
// Example using NetArchTest for architecture validation
[Test]
public void Domain_Should_Not_Have_Dependencies_On_Other_Layers()
{
    var result = Types.InAssembly(typeof(Order).Assembly)
        .ShouldNot()
        .HaveDependencyOnAll("YourCompany.YourDomain.Application", "YourCompany.YourDomain.Infrastructure")
        .GetResult();

    Assert.True(result.IsSuccessful);
}
```

## 6. Common Pitfalls and Solutions

### Typical Mistakes

**1. Domain Layer Violations:**

```csharp
// ❌ WRONG - Domain referencing infrastructure
public class Order
{
    public void Save()
    {
        // Direct database access in domain - VIOLATION!
        using var context = new DbContext();
        context.Orders.Add(this);
        context.SaveChanges();
    }
}

// ✅ CORRECT - Domain with repository abstraction
public class Order
{
    public void ProcessPayment(IPaymentProcessor processor)
    {
        // Domain logic using abstraction
        var result = processor.ProcessPayment(this.TotalAmount);
        if (result.IsSuccessful)
        {
            this.MarkAsPaid();
        }
    }
}
```

**2. Application Layer Violations:**

```csharp
// ❌ WRONG - Application directly using infrastructure
public class OrderService
{
    public async Task CreateOrder(CreateOrderRequest request)
    {
        using var context = new SqlServerDbContext(); // Direct infrastructure usage
        // ...
    }
}

// ✅ CORRECT - Application using abstractions
public class OrderService
{
    private readonly IOrderRepository _repository;
    
    public async Task CreateOrder(CreateOrderRequest request)
    {
        // Use repository abstraction
        await _repository.AddAsync(order);
    }
}
```

This comprehensive guide provides everything needed to set up a proper Onion Architecture implementation with clear separation of concerns and maintainable code structure.
