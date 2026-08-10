# OWASP Top 10:2025 — Audit Checklist

Official list, released Nov 2025 / finalised Jan 2026 (first update since 2021). Source: owasp.org/Top10/2025.
Work top to bottom — order reflects real-world prevalence, so it's also a good triage order.

---

## A01:2025 — Broken Access Control

*#1 risk. ~3.7% of tested apps affected. SSRF was folded into this category in 2025.*

**Checkpoints:**

- Every state-changing endpoint re-validates authorization **server-side** (never trust a client-side role check or a hidden form field).
- Default-deny: new routes/resources are inaccessible until explicitly granted, not accessible-until-restricted.
- Object-level checks: user A can't fetch/edit/delete user B's resource by changing an ID (IDOR).
- CORS is not `*` with credentials; origin allow-list is explicit.
- Server-side requests triggered by user input (webhooks, "fetch URL", image-from-URL, PDF renderers) validate/allow-list the target — this is SSRF, now scored under this category.
- No reliance on obscurity (unlisted endpoints, guessable tokens) as the only control.

**Detection heuristics:** search for route handlers with no auth middleware/decorator; `if (user.role == 'admin')` done client-side only; direct DB lookups by ID from request params with no ownership check; any `fetch(userProvidedUrl)` / `requests.get(user_input)` / `HttpClient.GetAsync(userUrl)` pattern.

---

## A02:2025 — Security Misconfiguration

*Jumped #5→#2. Nearly every tested app has at least one.*

**Checkpoints:**

- No default credentials, sample apps, or debug endpoints left in production builds.
- Verbose error messages / stack traces are not returned to the client in prod (`DEBUG=False`, custom error pages).
- Security headers set: CSP, `X-Content-Type-Options`, `X-Frame-Options`/frame-ancestors, HSTS.
- Cloud storage / DB permissions are not world-readable/writable by default (S3 buckets, Blob containers, exposed Redis/Mongo with no auth).
- Unnecessary services, ports, and features disabled (unused API verbs, admin panels not behind a separate network boundary).
- Config is externalized and environment-specific, not hardcoded per-environment in source.

**Detection heuristics:** `DEBUG = True` / `app.debug = true`; missing helmet/`SecurityHeadersMiddleware`; `.env` or credentials committed to repo; open CORS; Dockerfiles running as root with no `USER` directive; infra-as-code with `0.0.0.0/0` ingress or public storage.

---

## A03:2025 — Software Supply Chain Failures

*New category (expands "Vulnerable and Outdated Components"). Rarest in test data, highest average exploit+impact severity.*

**Checkpoints:**

- Dependencies are pinned/lockfiles committed (`package-lock.json`, `poetry.lock`, `go.sum`) — no floating majors.
- No known-CVE dependencies in use (cross-check manifest versions against advisories where feasible).
- Build/CI pipeline doesn't pull unpinned third-party actions/scripts (`uses: some/action@main` instead of a pinned SHA).
- No unofficial/unverified package sources or typosquat-risk package names.
- SBOM or equivalent dependency inventory exists for anything shipped to production, if the project's maturity warrants it.
- Signing/integrity verification on packages and container base images where the pipeline supports it.

**Detection heuristics:** unpinned CI action refs (`@main`, `@latest`); wildcard/range versions in manifests (`^`, `*`, no lockfile at all); base Docker images without a digest pin; any dependency install step lacking checksum verification.

---

## A04:2025 — Cryptographic Failures

*Renamed from "Sensitive Data Exposure" — root cause, not symptom. #2→#4.*

**Checkpoints:**

- Sensitive data (PII, credentials, tokens, payment data) encrypted at rest and in transit (TLS enforced, no plaintext fallback).
- Passwords hashed with a modern slow hash (bcrypt/argon2/scrypt) — never MD5/SHA1/plain, never a fast general-purpose hash alone.
- No hardcoded keys/secrets/IVs in source; keys rotated and sourced from a secrets manager, not the codebase.
- No custom-rolled crypto; only vetted libraries/algorithms (no ECB mode, no static IV reuse).
- Sensitive data excluded from logs, error messages, and URLs (query strings get logged/cached).
- Random values used for tokens/session IDs come from a CSPRNG, not `Math.random()`/`rand()`.

**Detection heuristics:** `md5(`, `sha1(` near "password"; hardcoded `apiKey =`/`secret =`/`private_key =` literals; `Math.random()` near "token"/"session"; `http://` for anything auth-related; TLS verification disabled (`verify=False`, `rejectUnauthorized: false`, `ServerCertificateCustomValidationCallback` bypass).

---

## A05:2025 — Injection

*#3→#5. Most CVEs of any category — spans XSS (high freq/low impact) to SQLi (low freq/high impact).*

**Checkpoints:**

- All DB queries use parameterized queries / prepared statements / ORM query builders — never string concatenation or f-strings with user input.
- All user input rendered in HTML is escaped/auto-escaped by the templating engine; CSP set as defense-in-depth against XSS.
- Command execution (`exec`, `system`, shell-outs) never interpolates raw user input; use argument arrays, not shell strings.
- XML parsers have external entity resolution disabled (XXE now lives here as an injection variant) — prefer JSON where possible.
- NoSQL queries built from user input use operators safely (no raw `$where`, no unsanitized object injection into Mongo queries).
- Input validated against an allow-list (type, length, format, range) server-side, not just client-side.

**Detection heuristics:** SQL built via string concat/f-string/`+`; `innerHTML =` / `dangerouslySetInnerHTML` / `v-html` with unsanitized input; `eval(`, `exec(`, `subprocess.call(..., shell=True)`, `os.system(`, backticks in Node with interpolated vars; XML parsers without `DTDHandler`/entity-resolution disabled; `$where` in Mongo queries.

---

## A06:2025 — Insecure Design

*#4→#6. Improving industry-wide, but still architecture-level, not a single bug.*

**Checkpoints:**

- Threat modeling evidence for sensitive flows (auth, payments, data export) — or at minimum, abuse-case thinking visible in the design.
- Business-logic limits enforced server-side (rate limits, max quantities, workflow-state transitions can't be skipped by calling out of order).
- Sensitive operations require re-authentication or step-up auth (changing email/password, high-value transactions).
- Trust boundaries are explicit — code doesn't silently trust data crossing from a less-trusted zone (client, third-party webhook, another microservice) without re-validating.
- Segregation of duties / least privilege reflected in the architecture, not just in access-control code.

**Detection heuristics:** this category is largely non-greppable — flag it by reading the flow: missing rate limiting on auth/payment endpoints, workflow state machines enforced only client-side, webhook handlers that trust payload contents without signature verification.

---

## A07:2025 — Authentication Failures

*Renamed from "Identification and Authentication Failures". Holding steady at #7.*

**Checkpoints:**

- No hardcoded/default credentials anywhere (including test/seed accounts left reachable in prod).
- Account lockout / rate limiting on login and password-reset endpoints (brute-force and credential-stuffing resistance).
- MFA available/enforced for privileged accounts.
- Session IDs regenerated on login/privilege change; sessions invalidated server-side on logout, not just client-side token deletion.
- Password-reset flows use single-use, time-limited, unguessable tokens — never reversible/predictable ones, never the old password sent back.
- No sensitive info leaked via differing responses ("user not found" vs "wrong password" — pick one generic message).

**Detection heuristics:** login endpoints with no rate limiting middleware; session tokens that are sequential/predictable; password-reset tokens that are short/guessable or don't expire; JWTs with `alg: none` accepted, or signature verification skipped.

---

## A08:2025 — Software or Data Integrity Failures

*Distinct from A03: this is about trust/verification at the artifact and data level, not the ecosystem level.*

**Checkpoints:**

- CI/CD pipeline artifacts are signed/verified before deploy; no unsigned auto-update mechanism.
- Deserialization of untrusted data uses safe formats (JSON with schema validation) — never native object deserialization (`pickle`, Java `ObjectInputStream`, PHP `unserialize`) on untrusted input.
- Webhooks and third-party callbacks verify a signature/HMAC before acting on the payload.
- Auto-update / plugin-loading mechanisms verify integrity (checksums/signatures) before executing fetched code.
- CI pipeline configuration itself is protected from unreviewed modification (branch protection on workflow files).

**Detection heuristics:** `pickle.loads(`, `yaml.load(` (unsafe loader), `ObjectInputStream`, PHP `unserialize(` on request/file data; webhook handlers with no signature check; CI workflows editable by any contributor with no required review.

---

## A09:2025 — Security Logging & Alerting Failures

*Renamed from "...and Monitoring". Emphasis added on alerting, not just recording.*

**Checkpoints:**

- Security-relevant events logged: auth successes/failures, access-control failures, input-validation failures, admin actions.
- Logs are tamper-resistant and centrally stored (not just local files an attacker can delete post-compromise).
- Logs don't contain sensitive data (passwords, full tokens, PII) in cleartext.
- Alerting exists for the events that matter (repeated auth failures, privilege escalation, anomalous access) — logging with nobody watching is close to logging nothing.
- Sufficient context in each log entry to support incident response (who, what, when, source IP/identity) without needing to correlate five other systems.

**Detection heuristics:** auth endpoints with no logging on failure; catch blocks that swallow security-relevant exceptions silently; logging statements that print full request bodies/tokens; no alerting/SIEM integration visible in config for a system handling sensitive data.

---

## A10:2025 — Mishandling of Exceptional Conditions

*New category. Improper error handling, logical errors, fail-open behavior.*

**Checkpoints:**

- Error/exception handling fails **closed** by default (deny access, reject the operation) rather than failing open.
- Every exception path from a security-relevant function is handled explicitly — no empty `catch {}` that lets execution continue as if it succeeded.
- Resource exhaustion / edge-case inputs (empty, oversized, malformed, null, unicode edge cases) don't crash into an insecure state.
- External service failures (auth provider down, payment gateway timeout) don't silently default to "allow".
- Retries/timeouts are bounded — no unbounded retry loops that become a self-inflicted DoS vector.

**Detection heuristics:** `catch (e) {}` / `except: pass` (empty or swallowing catch blocks) around auth/access-control logic; `if (authServiceDown) { allow = true }`-shaped fallback logic; missing timeout config on external calls; unguarded recursive/loop retry logic.

---

## Severity Guidance

- **Critical** — remote, unauthenticated, direct path to data breach / full compromise (e.g. unauthenticated SQLi, hardcoded prod secrets, broken auth on admin routes).
- **High** — requires some precondition (auth as low-priv user, specific config) but still leads to significant impact (IDOR exposing other users' data, stored XSS, SSRF reaching internal services).
- **Medium** — real weakness, harder to exploit or limited impact (missing security headers, verbose errors, weak-but-not-broken crypto).
- **Low** — best-practice gap, defense-in-depth missing, minimal standalone impact (missing rate-limit on a low-value endpoint, log verbosity issues).
