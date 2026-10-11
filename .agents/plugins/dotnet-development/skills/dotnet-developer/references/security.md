# Security for .NET Code

Secure by default. This file is the day-to-day developer checklist; for a full OWASP Top 10 audit of an existing codebase use the `security-auditor` skill if available.

## Contents

1. Input and output
2. Data access
3. Authentication and authorization
4. Secrets and configuration
5. Cryptography
6. Dependencies and supply chain
7. Logging and errors
8. HTTP surface
9. Regulated-environment notes
10. Quick review checklist

---

## 1. Input and output

- Validate every external input at the boundary (type, length, range, format, allow-list). Reject, do not "fix".
- Bind to DTOs, never directly to entities (prevents over-posting / mass assignment).
- Encode output for the context it lands in (HTML, URL, JSON). Do not build HTML/SQL/shell/LDAP by string concatenation.
- File uploads: size limit, allow-listed extensions and content type, generated server-side file names, stored outside the web root, scanned if the organization requires it.
- Deserialization: only into known types with `System.Text.Json`; never `BinaryFormatter` or type-name-driven polymorphic deserialization from untrusted data.
- Outgoing requests built from user input (URLs) need an allow-list to avoid SSRF.

## 2. Data access

- Parameterized queries only. EF Core LINQ is parameterized; for raw SQL use `FromSql` / `ExecuteSql` with interpolation (parameterized), not `FromSqlRaw` with concatenated strings.
- Least-privilege database accounts (the app does not need DDL rights at runtime; migrations run with a separate identity).
- Row/tenant filters applied centrally (global query filters), not by every developer remembering a `Where`.

## 3. Authentication and authorization

- Use the platform: ASP.NET Core authentication handlers, OIDC/OAuth2 with the organization's IdP. Do not write your own token or session scheme.
- Authorize by **policy** (`[Authorize(Policy = "...")]` / `.RequireAuthorization("...")`), with a fallback policy that denies anonymous access by default; opt out explicitly (`AllowAnonymous`) and review each one.
- Check authorization on the resource, not only on the endpoint (can this user see *this* customer?). Broken object-level authorization is the most common API flaw.
- Validate token audience, issuer, lifetime and signature; keep lifetimes short.
- Test both allowed and denied paths.

## 4. Secrets and configuration

- No secrets, connection strings with passwords, or tokens in source control, `appsettings.json`, images or logs.
- Local development: `dotnet user-secrets`. Deployed: the platform's secret store (e.g. Azure Key Vault) with managed identity; no static credentials where an identity can be used.
- Secrets arrive through the configuration system and are bound to options; they are never logged (override `ToString` on options holding them or exclude them).
- Rotate on suspicion; design so rotation needs no code change.

## 5. Cryptography

- Never invent crypto. Use `System.Security.Cryptography`; random values via `RandomNumberGenerator`, not `Random`.
- Passwords: use a slow adaptive hash (the framework's `PasswordHasher<T>`, or Argon2/bcrypt/PBKDF2 with proper parameters); never fast hashes (MD5/SHA-1/SHA-256 alone).
- Prefer authenticated encryption (AES-GCM); TLS 1.2+ everywhere; no custom certificate validation that returns `true`.
- Data Protection API keys persisted to a shared, protected store in multi-instance deployments.

## 6. Dependencies and supply chain

- Every package is a dependency you answer for: purpose in the PR description, license checked, maintained, no known vulnerabilities.
- Build runs with NuGet audit on (`NuGetAudit`, `NuGetAuditMode=all`, see `assets/Directory.Build.props`) so direct **and transitive** vulnerabilities surface as warnings (errors in CI).
- Periodically: `dotnet list package --vulnerable --include-transitive`, `--deprecated`, `--outdated`.
- Central Package Management and, where required, lock files (`RestorePackagesWithLockFile`) for reproducible restores.
- Use the organization's NuGet feed/proxy if one exists; avoid ad-hoc sources.
- Keep the runtime on a supported version (.NET 8/9 end of support: 10 Nov 2026).
- If the organization requires an SBOM or a register of third-party components, generate it in CI (e.g. a CycloneDX tool) and keep it with the build artifacts.

## 7. Logging and errors

- Do not log secrets, tokens, full card/IBAN numbers, or personal data beyond what operations strictly need; mask what must appear.
- Sanitize user-controlled values in log templates (use structured properties, never concatenation) to avoid log injection.
- Return problem details without stack traces or internal exception text. Log the detail server-side with the correlation id, return the id to the client.
- Audit-relevant actions (authN/authZ decisions, privileged changes, data exports) are logged as structured events with who/what/when.

## 8. HTTP surface

- HTTPS only; HSTS in production; redirect HTTP.
- CORS: explicit origins, methods and headers - never `AllowAnyOrigin` with credentials.
- Rate limiting (`AddRateLimiter`) on authentication and expensive endpoints; request size limits and timeouts.
- Security headers (CSP, `X-Content-Type-Options`, `Referrer-Policy`) for anything serving a browser.
- Anti-forgery for cookie-authenticated, state-changing browser endpoints.

## 9. Regulated-environment notes

In a banking context (the team works under frameworks such as DORA and supervisory expectations like EBA/ECB guidelines), these habits make audits and incident reviews easier. Treat the list as engineering hygiene, and confirm the organization's specific controls before citing a requirement:

- Traceability: PR -> work item -> build -> artifact -> deployment, with immutable build artifacts.
- Change control and four-eyes review on production-bound changes (mandatory PR review; no direct pushes to main).
- Third-party/ICT dependency awareness: know which libraries and external services each application depends on and why (see supply chain above).
- Resilience: timeouts, retries with limits, circuit breakers, graceful degradation, health/readiness probes, documented rollback.
- Observability sufficient for incident reconstruction: correlation ids, structured logs, metrics, alerts with owners.
- Data protection: data minimization, retention, encryption in transit and at rest, personal-data handling documented.
- Exit/portability thinking for critical external providers: keep them behind an interface (anti-corruption layer).

## 10. Quick review checklist

- [ ] All inputs validated at the boundary; DTOs, not entities, are bound
- [ ] No string-built SQL/HTML/shell; parameterized queries
- [ ] Endpoints require authorization by default; resource-level checks present
- [ ] No secrets in code, config files, logs or images
- [ ] No custom crypto; `RandomNumberGenerator` for security randomness
- [ ] Packages audited (direct + transitive); runtime supported
- [ ] Errors return problem details without internals; logs carry correlation id and no PII/secrets
- [ ] CORS, HTTPS/HSTS, rate limiting configured intentionally
