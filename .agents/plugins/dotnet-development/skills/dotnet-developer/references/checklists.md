# Checklists

Use the one that matches the moment. Tick honestly; "n/a" is allowed, "I'll do it later" is not.

## Contents

1. Definition of Done (per change)
2. PR review checklist (for reviewers)
3. New project / solution checklist
4. Release readiness checklist
5. Pre-merge command sequence
6. Code review comment format

---

## 1. Definition of Done (per change)

**Design**

- [ ] Domain model captures the business rule; invariants enforced inside the domain
- [ ] Dependencies point inward (Domain references nothing)
- [ ] No business rule in controllers, repositories or DTO mappers

**Code**

- [ ] Targets `net10.0`; nullable enabled; zero warnings (warnings-as-errors passes)
- [ ] Naming: PascalCase / `_camelCase` private fields / `I` interfaces / `Async` suffix
- [ ] File-scoped namespace, Allman braces, `#region Fields`, final `return` on its own line
- [ ] Constructor injection with `ArgumentNullException.ThrowIfNull`
- [ ] `is null` / `is not null`; no redundant null checks
- [ ] Async end to end, `CancellationToken` passed down, no `.Result`/`.Wait()`, no `async void`
- [ ] Pattern matching / switch expressions / `nameof` where applicable
- [ ] No magic strings/numbers for domain concepts; no commented-out code; TODOs have a ticket

**Tests**

- [ ] Unit tests for the domain rules and critical paths (success **and** failure)
- [ ] Null-parameter validation tests on public entry points
- [ ] NUnit + NSubstitute only; `Assert.That`; AAA banners; names `Method_Scenario_Expected`
- [ ] Tests are independent and deterministic

**Documentation**

- [ ] XML docs on every new/changed public member (summary, params, returns, exceptions)
- [ ] Inline comments explain *why* for non-obvious decisions
- [ ] README / ADR / CHANGELOG updated if behavior, config or architecture changed

**Operations and security**

- [ ] Structured logging with templates; no secrets/PII in logs
- [ ] Configuration via validated options; no secrets in source
- [ ] Inputs validated; queries parameterized; authorization checked on the resource
- [ ] New package: purpose, license and vulnerabilities checked
- [ ] Health checks / metrics / correlation id intact for new endpoints and dependencies

## 2. PR review checklist (for reviewers)

Work top-down; stop at the first Blocker section that fails and send it back.

1. **Correctness (Blocker)**: does it do what the ticket says? Edge cases (null, empty, boundaries, concurrency, time zones, rounding of money)? Idempotency where retried?
2. **Security (Blocker)**: section 10 of `security.md`.
3. **Design (Major)**: right layer? Domain invariants protected? Over-engineered (interface for one implementation, new abstraction without a second use)? Under-engineered (logic in controller)?
4. **Tests (Major)**: do they fail if the behavior breaks? Failure paths covered? Mocks only at boundaries? No forbidden libraries?
5. **Async and resources (Major)**: cancellation, disposal, `HttpClient` via factory, no sync-over-async, no unbounded queries.
6. **Observability (Major)**: right log levels, no sensitive data, correlation id, meaningful error messages.
7. **Style and naming (Minor)**: handled by `.editorconfig`/analyzers; do not argue style a tool can enforce - fix the tool.
8. **Docs (Minor)**: XML docs accurate, README/ADR updated.
9. **Nits**: prefix with "nit:" and never block on them.

Reviewer rules: only high-confidence findings as statements; uncertain ones as questions. Explain the *why*. Offer the fix. Recognize what is good.

## 3. New project / solution checklist

- [ ] Solution with `src/` and `tests/`; project names follow `Company.Product.Layer`
- [ ] `Directory.Build.props`, `Directory.Packages.props`, `.editorconfig` at the repo root
- [ ] `net10.0`, nullable, implicit usings, warnings as errors, NuGet audit, XML docs on
- [ ] Test project `[ProjectName].Tests` with `GlobalUsings.cs`, NUnit, NSubstitute, NUnit.Analyzers, coverlet
- [ ] `Program.cs`: options validation (`ValidateOnStart`), ProblemDetails + exception handler, structured logging, health checks (live/ready), OpenAPI, auth fallback policy
- [ ] `.gitignore`, `README.md`, `docs/adr/0001-...md`, `CHANGELOG.md` for libraries
- [ ] CI pipeline: restore, build, format check, test + coverage, vulnerable/deprecated package scan, publish artifact
- [ ] Containerization via SDK publish; non-root; no secrets in the image
- [ ] Branch protection: PR required, reviews required, CI must pass

## 4. Release readiness checklist

- [ ] CI green on the release commit; artifact is the one that will be deployed
- [ ] No vulnerable or deprecated packages; runtime still in support
- [ ] Configuration for the target environment present and validated at startup
- [ ] Database migrations reviewed, backward-compatible with the previous app version, rollback plan written
- [ ] Health/readiness endpoints respond; dashboards and alerts exist for the new behavior
- [ ] Feature flags / gradual rollout considered for risky changes
- [ ] Runbook updated; owners know how to roll back
- [ ] Release notes / CHANGELOG updated; breaking API changes announced and versioned

## 5. Pre-merge command sequence

```bash
dotnet restore
dotnet build -c Release -warnaserror
dotnet format --verify-no-changes
dotnet test -c Release --no-build --collect:"XPlat Code Coverage"
dotnet list package --vulnerable --include-transitive
dotnet list package --deprecated
dotnet list package --outdated      # informational
```

If `dotnet format --verify-no-changes` fails, run `dotnet format` and commit the result separately from functional changes.

## 6. Code review comment format

```
[Major] OrderService.cs:42 - Result of PlaceOrderAsync is not awaited.
Why: exceptions are lost and the request completes before the order is saved.
Fix: `await _orders.PlaceOrderAsync(order, cancellationToken);`
```

Severity tags: `[Blocker]`, `[Major]`, `[Minor]`, `[Nit]`, `[Question]`.
