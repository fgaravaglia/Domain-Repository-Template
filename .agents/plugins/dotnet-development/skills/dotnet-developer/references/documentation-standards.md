# Documentation Standards

Good documentation answers **why** and **how to use**, not what the code already says. It keeps the code maintainable, helps collaboration, and feeds automatic API docs.

## Contents

1. Scope: what must be documented
2. Tag reference
3. Quality rules
4. Patterns (examples)
5. Beyond XML docs: README, ADR, changelog, OpenAPI
6. Generation and CI
7. Documentation checklist

---

## 1. Scope

**Required** (build fails on missing docs when `GenerateDocumentationFile` + `TreatWarningsAsErrors` are on - see `assets/Directory.Build.props`):

- Every public class, interface, record, enum (and its members)
- Public methods, properties, fields, events, constructors, operators

**Encouraged** (internal/private):

- Complex internal logic and non-obvious implementations
- Critical business rules
- Integration points between layers
- Any place where you made a trade-off: say why (inline `//` comment)

## 2. Tag reference

| Tag | Use it for | Notes |
| --- | --- | --- |
| `<summary>` | One-sentence purpose | Mandatory on every public member. Active voice. |
| `<param name="x">` | Meaning, constraints, units | State null/empty/range rules |
| `<returns>` | What comes back and when | Cover empty results; avoid "null if invalid" - throw instead |
| `<exception cref="T">` | Each exception and its trigger | Must match the implementation |
| `<remarks>` | Context, algorithm, ordering, thread-safety | Use `<para>` and `<list>` for structure |
| `<example>` + `<code>` | Usage that compiles | Keep examples working and current |
| `<see cref="T"/>` / `<seealso cref="T"/>` | Links to related types/members | Verify the target exists |
| `<see langword="null"/>` | Keywords: `null`, `true`, `false` | Instead of writing the bare word |
| `<paramref name="x"/>` / `<typeparamref name="T"/>` | Refer to a parameter inside prose | |
| `<typeparam name="T">` | Generic parameter and its constraints | |
| `<inheritdoc/>` | Implementations, overrides | Add `<remarks>` only for what differs |
| `<c>` | Inline code | |
| `<list type="bullet | number | table">` | Lists and tables | |

XML escaping: write `&lt;`, `&gt;`, `&amp;` inside `<code>` and prose when needed; generic types in `cref` use braces: `<see cref="IEquatable{T}"/>`.

## 3. Quality rules

- Active voice; short sentences; no redundant restatement of the member name ("Gets the name" on `Name` is noise - say what the name *is*).
- Focus on the "why" and the contract; include business context where it matters.
- Consistent terminology (use the domain's ubiquitous language), consistent tense.
- Docs change in the same commit as the code; reviewers check them.
- Every `<exception>` is actually thrown; every `<param>` name matches the signature.
- Examples compile and show the typical usage first, advanced usage second.
- No commented-out code, no changelog in comments (that is git's job).

## 4. Patterns

### Class with domain context

```csharp
/// <summary>
/// Manages customer domain operations including validation, creation, and lifecycle management.
/// </summary>
/// <remarks>
/// Coordinates between customer aggregates and domain services.
/// All operations maintain domain invariants and trigger the appropriate domain events.
/// </remarks>
public class CustomerDomainService : ICustomerDomainService
{
}
```

### Method with full contract

```csharp
/// <summary>
/// Updates customer information, enforcing validation and business rules.
/// </summary>
/// <param name="customerId">Identifier of the customer to update.</param>
/// <param name="updateData">New customer information.</param>
/// <param name="cancellationToken">Token to cancel the operation.</param>
/// <returns>The updated <see cref="Customer"/>.</returns>
/// <exception cref="ArgumentNullException"><paramref name="updateData"/> is <see langword="null"/>.</exception>
/// <exception cref="CustomerNotFoundException">No customer exists with <paramref name="customerId"/>.</exception>
/// <exception cref="ValidationException">
/// <paramref name="updateData"/> is invalid:
/// <list type="bullet">
/// <item>Email format is invalid</item>
/// <item>Phone number format is incorrect</item>
/// </list>
/// </exception>
/// <exception cref="DomainException">A business rule prevents the update (e.g. the account is suspended).</exception>
public async Task<Customer> UpdateCustomerAsync(
    CustomerId customerId,
    CustomerUpdateData updateData,
    CancellationToken cancellationToken)
{
    // Implementation
}
```

### Interface + implementation (`inheritdoc`)

```csharp
public interface IRepository<T> where T : Entity
{
    /// <summary>Adds a new entity to the repository.</summary>
    /// <param name="entity">The entity to add.</param>
    /// <returns>The added entity with updated metadata.</returns>
    Task<T> AddAsync(T entity);
}

public class CustomerRepository : IRepository<Customer>
{
    /// <inheritdoc/>
    public Task<Customer> AddAsync(Customer entity)
    {
        // Implementation
    }
}
```

### Generic type

```csharp
/// <summary>Generic repository base class providing common data operations.</summary>
/// <typeparam name="TEntity">The entity type. Must inherit from <see cref="Entity"/> and have a parameterless constructor.</typeparam>
/// <typeparam name="TId">The identifier type. Must be a value type implementing <see cref="IEquatable{T}"/>.</typeparam>
public abstract class Repository<TEntity, TId> : IRepository<TEntity, TId>
    where TEntity : Entity<TId>, new()
    where TId : struct, IEquatable<TId>
{
}
```

### Business rules as a table

```csharp
/// <remarks>
/// <list type="table">
/// <listheader><term>Loyalty tier</term><description>Base discount</description></listheader>
/// <item><term>Bronze</term><description>2% on orders over 100</description></item>
/// <item><term>Silver</term><description>5% on all orders, 7% over 500</description></item>
/// </list>
/// The combined discount is capped at 35% of the order value.
/// </remarks>
```

### Example block

```csharp
/// <example>
/// <code>
/// if (CustomerId.TryParse("12345", out var id))
/// {
///     var customer = await repository.GetByIdAsync(id, cancellationToken);
/// }
/// </code>
/// </example>
```

## 5. Beyond XML docs

- **README.md** per repository/service: purpose, how to build/run/test, configuration keys (names, not values), dependencies, owners, links.
- **ADR (Architecture Decision Record)** in `docs/adr/NNNN-title.md` for decisions that are expensive to reverse: context, options, decision, consequences. Use the `easp-architecture-decision` skill if available.
- **CHANGELOG.md** (Keep a Changelog style) for libraries and public APIs; mention breaking changes first.
- **OpenAPI**: public endpoints carry summaries, response types (`ProducesResponseType` / `TypedResults`), and examples; XML docs feed the generated spec where the toolchain supports it. Version the API and document deprecations.
- **Runbook** for services: how to tell it is healthy, common failures, how to roll back.

## 6. Generation and CI

```xml
<!-- Enable XML documentation generation (in Directory.Build.props or the .csproj) -->
<PropertyGroup>
  <GenerateDocumentationFile>true</GenerateDocumentationFile>
</PropertyGroup>
```

`GenerateDocumentationFile` is enough; an explicit `<DocumentationFile>` path is only needed for a custom location.

- Treat missing public docs (CS1591) as errors in CI.
- Generate API docs with DocFX (or equivalent) in the pipeline and review the output periodically.
- Verify cross-references (`cref`) and compile code samples in review.

## 7. Documentation checklist

- [ ] Every public type/member has `<summary>`
- [ ] `<param>` for every parameter, constraints stated; `<returns>` explains empty/edge results
- [ ] `<exception>` matches what the code really throws
- [ ] `<remarks>` explains rules, ordering, side effects, thread-safety where relevant
- [ ] `<example>` for non-trivial public APIs
- [ ] `<inheritdoc/>` used on implementations instead of copy-paste
- [ ] `cref` targets exist; no broken links
- [ ] Inline comments say *why*, not *what*; no commented-out code
- [ ] README / ADR / CHANGELOG updated when behavior or decisions changed
- [ ] Docs build without warnings
