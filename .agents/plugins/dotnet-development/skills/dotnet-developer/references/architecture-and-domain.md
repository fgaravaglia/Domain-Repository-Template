# Architecture and Domain-First Design

Principle: balance technical agility with the business goal. Start from the domain model; add only the structure the problem pays for.

## Contents

1. Layers and the dependency rule
2. Domain building blocks
3. Application layer
4. Infrastructure
5. API layer
6. Solution layout
7. Worked example: payment initiation
8. Decision guide (when to add structure)
9. Scaffolding a new project

---

## 1. Layers and the dependency rule

```
Api  ->  Application  ->  Domain
  \          |
   -> Infrastructure (implements interfaces owned by Application/Domain)
```

- **Domain**: entities, value objects, domain events, domain services, domain exceptions. No dependency on EF, ASP.NET, HTTP, JSON, or any framework.
- **Application**: use cases (commands/queries and their handlers), interfaces for what it needs from the outside (`IPaymentRepository`, `IClock`, `IMessagePublisher`), DTOs, validation of requests.
- **Infrastructure**: EF Core `DbContext` and mappings, repositories, HTTP clients, messaging, file storage. Implements the interfaces above.
- **Api (host)**: endpoints/controllers, authentication, DI composition root, ProblemDetails, health checks, OpenAPI.

Dependencies point inward. Domain references nothing. Why: business rules survive a change of database, transport or framework, and can be tested without any of them.

## 2. Domain building blocks

- **Entity**: identity + lifecycle. State changes only through methods that enforce invariants (`private set`).
- **Value object**: no identity, immutable, equality by value. Use `record` / `readonly record struct` (`Money`, `Iban`, `EmailAddress`).
- **Strongly-typed ids**: `readonly record struct CustomerId(Guid Value)` - prevents passing an `OrderId` where a `CustomerId` is expected.
- **Aggregate root**: consistency boundary; other code holds references to the root only. Keep aggregates small; reference other aggregates by id.
- **Invariants** live in constructors/factory methods (`Customer.Register(...)`), so an invalid object cannot exist.
- **Domain events**: facts that happened (`PaymentAuthorized`); raised by the aggregate, dispatched by the application layer after the transaction commits.
- **Domain exceptions**: `DomainException` (and subtypes) for business-rule violations; mapped to 4xx at the API.
- **Domain services**: stateless logic spanning aggregates; only when no aggregate is the natural owner.
- Use the ubiquitous language: class and method names are the words the business uses.

## 3. Application layer

- One use case = one class/handler (`InitiatePaymentHandler`) with a single public method. Commands change state; queries read (use projections, `AsNoTracking`).
- Orchestrates: load aggregate -> call domain method -> persist -> publish events. No business rules here; if you write an `if` about a business rule, it belongs in the domain.
- Transaction boundary = one use case. Cross-service consistency by outbox + idempotent consumers, not distributed transactions.
- Validation: shape/format of the request here (FluentValidation is a separate library from FluentAssertions - allowed unless the team says otherwise; or data annotations); business validation in the domain.
- Make handlers idempotent where clients may retry (payments, orders): accept an idempotency key and return the original result on replay.

## 4. Infrastructure

- Repositories per aggregate root (see data access in coding standards). Map domain <-> persistence with EF configuration classes (`IEntityTypeConfiguration<T>`), keep EF attributes out of the domain.
- Outbox table for events that must not be lost.
- External calls behind an interface owned by the application layer (anti-corruption layer): the rest of the code never sees the vendor's DTOs.
- All outgoing HTTP via `IHttpClientFactory` + resilience.

## 5. API layer

- Minimal APIs or controllers: pick one per service and stay consistent. Group endpoints by feature.
- Request/response DTOs are separate from domain types. Never expose entities.
- Errors: RFC 9457 `ProblemDetails`; consistent codes (400 validation, 401/403 auth, 404 missing, 409 conflict/idempotency, 422 business rule, 5xx never leaks details).
- Versioning from day one (`/v1/...` or header); deprecate explicitly.
- List endpoints: pagination (page/size or cursor), bounded size, deterministic sort.
- Authentication/authorization via policies (see security reference); health checks `/health/live` and `/health/ready`.
- OpenAPI document generated and reviewed as part of the PR.

## 6. Solution layout

Adapt to the structure of the `Domain-Repository-Template` repo if it is present in the workspace; otherwise:

```
src/
  Contoso.Payments.Domain/
  Contoso.Payments.Application/
  Contoso.Payments.Infrastructure/
  Contoso.Payments.Api/
tests/
  Contoso.Payments.Domain.Tests/
  Contoso.Payments.Application.Tests/
  Contoso.Payments.Api.Tests/          (integration)
docs/
  adr/
Directory.Build.props
Directory.Packages.props
.editorconfig
```

Feature folders inside each project (`Payments/`, `Refunds/`) beat technical folders (`Models/`, `Services/`) once there is more than one feature.

## 7. Worked example: payment initiation

Hypothetical: a client calls `POST /v1/payments` to initiate a payment. Retries are common (mobile networks), and a duplicate payment is a real business loss.

**Domain** - the invariants first:

```csharp
namespace Contoso.Payments.Domain;

/// <summary>Payment aggregate root. Guarantees that an authorized payment can never be modified.</summary>
public sealed class Payment
{
    #region Fields

    private readonly List<IDomainEvent> _events = [];

    #endregion

    public PaymentId Id { get; }
    public Money Amount { get; }
    public PaymentStatus Status { get; private set; }

    private Payment(PaymentId id, Money amount)
    {
        Id = id;
        Amount = amount;
        Status = PaymentStatus.Pending;
    }

    /// <summary>Creates a pending payment.</summary>
    /// <exception cref="DomainException">The amount is not strictly positive.</exception>
    public static Payment Initiate(PaymentId id, Money amount)
    {
        // Why here: a zero or negative payment must be impossible to represent, whichever entry point creates it.
        if (amount.Value <= 0)
        {
            throw new DomainException("Payment amount must be greater than zero.");
        }

        return new Payment(id, amount);
    }

    /// <summary>Marks the payment as authorized and records the fact as a domain event.</summary>
    /// <exception cref="DomainException">The payment is not pending.</exception>
    public void Authorize()
    {
        if (Status != PaymentStatus.Pending)
        {
            throw new DomainException($"Cannot authorize a payment in status {Status}.");
        }

        Status = PaymentStatus.Authorized;
        _events.Add(new PaymentAuthorized(Id));
    }
}
```

**Application** - orchestration + idempotency:

```csharp
public sealed class InitiatePaymentHandler
{
    #region Fields

    private readonly IPaymentRepository _payments;
    private readonly IIdempotencyStore _idempotency;

    #endregion

    public InitiatePaymentHandler(IPaymentRepository payments, IIdempotencyStore idempotency)
    {
        ArgumentNullException.ThrowIfNull(payments);
        ArgumentNullException.ThrowIfNull(idempotency);

        _payments = payments;
        _idempotency = idempotency;
    }

    /// <summary>Initiates a payment; replays of the same idempotency key return the original result.</summary>
    public async Task<PaymentId> HandleAsync(InitiatePayment command, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        // Why first: the check must happen before any side effect, or a retry could create a second payment.
        if (await _idempotency.TryGetAsync(command.IdempotencyKey, cancellationToken) is { } existing)
        {
            return existing;
        }

        var payment = Payment.Initiate(PaymentId.New(), new Money(command.Amount, command.Currency));
        await _payments.AddAsync(payment, cancellationToken);
        await _idempotency.StoreAsync(command.IdempotencyKey, payment.Id, cancellationToken);

        return payment.Id;
    }
}
```

**Tests** (domain first, no mocks): `Initiate_WithZeroAmount_ThrowsDomainException`, `Authorize_WhenAlreadyAuthorized_ThrowsDomainException`. Then handler tests with NSubstitute: `HandleAsync_WithReplayedKey_ReturnsOriginalIdAndDoesNotAddPayment`.

Takeaway: the rule "no duplicate payment" is protected at the layer where it can be tested fastest, and the API layer is left with nothing but mapping.

## 8. Decision guide

| Question | Default | Add more structure when |
| --- | --- | --- |
| Separate projects per layer? | Yes for services with real business rules | Tiny CRUD/BFF: a single project with folders is fine |
| Repository abstraction over EF? | Per aggregate root | Never "one per table" |
| CQRS (separate read model)? | Handlers split commands/queries in code | Separate stores only when read/write loads or shapes diverge |
| Domain events? | In-process, after commit | Outbox + broker when other services must react |
| MediatR-style mediator? | Not by default; plain handlers injected where needed | Only if cross-cutting pipeline behaviors justify it (check current licensing/terms of the library first) |
| Microservice vs modular monolith? | Modular monolith until team/scale forces a split | Independent deploy/scale/ownership is a proven need |

Flag when a technically valid choice will be hard for the team to adopt (new pattern, new library, extra project per feature) - recommend the smallest step and who has to agree.

## 9. Scaffolding a new project

1. `dotnet new sln`, create `src/` and `tests/` projects (`classlib`, `webapi`, `nunit`).
2. Copy `assets/Directory.Build.props` and `assets/.editorconfig` to the repo root; add `Directory.Packages.props` for central package management.
3. Test projects: add packages, `GlobalUsings.cs`, and `assets/TestClassTemplate.cs` as the starting point.
4. Add health checks, ProblemDetails, structured logging and options validation in `Program.cs` from the first commit.
5. Add CI: restore, build (warnings as errors), format check, test + coverage, vulnerable-package scan.
6. Create `README.md` and `docs/adr/0001-record-architecture-decisions.md`.
7. Run the new-project checklist in `references/checklists.md`.
