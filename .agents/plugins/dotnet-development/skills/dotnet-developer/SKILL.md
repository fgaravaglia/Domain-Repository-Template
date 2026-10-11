---
name: dotnet-developer
description: Team-standard way to write, review, test and document .NET / C# code (.NET 10 LTS, C# 14, domain-first design, NUnit + NSubstitute, XML docs, secure-by-default, regulated-environment friendly). Use this skill whenever the user works on C#/.NET - classes, ASP.NET Core APIs, microservices, class libraries, EF Core, dependency injection, async code, NUnit unit tests, XML documentation, csproj / Directory.Build.props / .editorconfig, code review, PR checklists, "definition of done" - even if they only say "scrivimi una classe", "fai la review di questo codice", "scrivi gli unit test", "documenta questo servizio", "imposta un nuovo progetto dotnet", or share .cs / .csproj / .sln files. Prefer this skill over generic C# knowledge: it encodes the team's non-obvious rules (forbidden libraries, naming, region layout, test style).
---

# dotnet-developer

Opinionated playbook for building .NET services the way this team does it. The goal is code that a reviewer can approve without a style discussion: consistent, documented, tested, and safe to run in a regulated environment.

Source of truth for the standards is the repo `fgaravaglia/Domain-Repository-Template` (`docs/01-coding-standards`). This skill is a snapshot of those docs (Oct 2026) plus fixes and additions. If the repo is available in the workspace and differs from this skill, the repo wins - and tell the user what drifted.

## Step 1 - Pick the references you need

Read only what the task needs (progressive disclosure keeps context lean).

| Task                                                     | Read                                                                             |
| -------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Write or extend production code                          | `references/coding-standards.md`, `references/architecture-and-domain.md`        |
| Review code / a PR                                       | `references/checklists.md` (PR review section), `references/coding-standards.md` |
| Write or fix unit tests                                  | `references/nunit-testing-standards.md`, `assets/TestClassTemplate.cs`           |
| Document code (XML docs, README, ADR)                    | `references/documentation-standards.md`                                          |
| New solution / project scaffolding                       | `references/architecture-and-domain.md`                                          |
| Auth, secrets, input handling, data access, dependencies | `references/security.md`                                                         |
| "Is it done?" / pre-merge                                | `references/checklists.md`                                                       |
| User points out a contradiction in the standards         | `references/standards-decisions.md`                                              |

Most real tasks need two or three files (e.g. new feature = coding + architecture + nunit + documentation).

## Step 2 - Work domain-first

Start from the domain model, not from controllers or tables. Reason: the domain carries the business rules and invariants; if it is right, the outer layers are mostly plumbing, and tests of the domain are fast and need no mocks.

1. Name the domain concepts in the user's language (entities, value objects, invariants, events).
2. Write the domain types with invariants enforced in constructors / factory methods.
3. Write the domain unit tests next to them.
4. Add application services (use cases) and the interfaces they need (`IXxxRepository`, `IClock`...).
5. Add infrastructure (EF Core, HTTP clients, messaging) implementing those interfaces.
6. Add the API surface last (endpoints, DTOs, validation, ProblemDetails).
7. Document public API, then run the Definition of Done (`references/checklists.md`).

If the request is small (a single method, a quick fix), skip the ceremony - but keep the rules below.

## Non-negotiables (apply to every .cs file you touch)

1. **Target `net10.0` (LTS) and the default C# of the SDK (C# 14).** Use .NET 8/9 only when maintaining an existing project; both reach end of support on 10 Nov 2026. Never start a new project on them without telling the user why that is a risk.
2. File-scoped namespaces, implicit usings, `<Nullable>enable</Nullable>`.
3. Naming: PascalCase for types/methods/properties/public members; `_camelCase` for private fields; `I` prefix for interfaces.
4. Allman braces: newline before every opening `{`. Final `return` of a method on its own line.
5. Private fields live in a `#region Fields` block at the top of the class.
6. Constructor injection with `ArgumentNullException.ThrowIfNull(...)`; depend on interfaces.
7. `is null` / `is not null`, never `== null`. Do not null-check values the type system already guarantees non-null.
8. `async`/`await` for all I/O. Return `Task` / `Task<T>` (never `async void`), accept `CancellationToken`, never block with `.Result` / `.Wait()`.
9. Pattern matching, switch expressions, `nameof` instead of string literals for member names.
10. XML doc comments on every public type and member. Inline comments explain **why** a decision was made, not what the code does.
11. Tests: NUnit + NSubstitute, `Assert.That` constraint model. **Moq and FluentAssertions are forbidden.**
12. Structured logging with message templates (never string interpolation), no secrets or PII in logs. Parameterized queries only.

## Style sample

This is what "done right" looks like - use it as the visual target:

```csharp
namespace Contoso.Customers.Domain;

/// <summary>
/// Customer aggregate root. Owns the rules around contact data so that no other
/// layer can create or mutate a customer into an invalid state.
/// </summary>
public sealed class Customer
{
    #region Fields

    private readonly List<string> _tags = [];

    #endregion

    /// <summary>Gets the unique identifier of the customer.</summary>
    public CustomerId Id { get; }

    /// <summary>Gets the validated e-mail address used for communication.</summary>
    public string Email { get; private set; }

    private Customer(CustomerId id, string email)
    {
        Id = id;
        Email = email;
    }

    /// <summary>
    /// Registers a new customer.
    /// </summary>
    /// <param name="id">Identifier generated by the caller (keeps the domain free of ID generation concerns).</param>
    /// <param name="email">E-mail address. Cannot be <see langword="null"/> or whitespace.</param>
    /// <returns>A valid <see cref="Customer"/>.</returns>
    /// <exception cref="ArgumentException"><paramref name="email"/> is null, empty or whitespace.</exception>
    /// <exception cref="DomainException">The e-mail format is invalid.</exception>
    public static Customer Register(CustomerId id, string email)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(email);

        // Why a factory and not a public constructor: the invariant must hold from the
        // first instant, and a static method gives us a named, intention-revealing entry point.
        if (!email.Contains('@'))
        {
            throw new DomainException($"'{email}' is not a valid e-mail address.");
        }

        return new Customer(id, email);
    }
}
```

## Output conventions

- **Producing code:** deliver complete files, not fragments, unless the user asks for a snippet. More than ~20 lines of code goes in a file.
- **Reviewing code:** group findings by severity - Blocker (bug, security, data loss), Major (design, missing tests), Minor (style, naming), Nit. Make only high-confidence findings; if unsure, phrase it as a question. For each finding give the line/member, the reason, and the fix. Close with the 1-3 most valuable changes to make first.
- **Explaining / teaching:** the source docs contain bullets like "Guide users through...", "Demonstrate...". Treat those as _teach mode_: only when the user asks to learn or understand. Default mode is to produce working, standard-compliant code with brief reasoning.
- **Conflicts with the standards:** if the user's request would break a rule above, say so in one line and offer the compliant alternative; do not silently comply or silently deviate.
- **Unsure about a package, API or version?** Check current docs rather than relying on memory - the .NET ecosystem moves every November. Install packages with `dotnet add package <Name>` (no hand-pinned versions in examples).
- **Language:** code, comments and XML docs in English. Talk to the user in their language.

## When a rule seems wrong

The standards were written by one person over time and some lines conflict or have aged (see `references/standards-decisions.md` for the ones already resolved). If you find a new conflict, surface it to the user as a decision to make, with a recommendation - don't pick quietly.
