# React / Next.js Security Audit Checklist

Reference file for `security-auditor` skill. Load when stack is React, Next.js, or TypeScript frontend.

## OWASP Top 10:2025 Category Mapping

This file predates the 2025 taxonomy and is organised by practical bucket, not by category number.
Use this table when the report needs the `A0X:2025` tag per finding:

| Section below | OWASP 2025 Category |
| --- | --- |
| 1. Secrets & Credentials | A04:2025 - Cryptographic Failures |
| 2. Dependencies & Supply Chain | A03:2025 - Software Supply Chain Failures |
| 3a. Client-Side Auth Checks | A01:2025 - Broken Access Control |
| 3b. JWT in localStorage | A04:2025 - Cryptographic Failures (token handling) |
| 3c. Next.js Middleware Auth | A01:2025 - Broken Access Control |
| 3d. Route Handler Auth | A01:2025 - Broken Access Control |
| 4a. XSS — dangerouslySetInnerHTML | A05:2025 - Injection |
| 4b. XSS — href Injection | A05:2025 - Injection |
| 4c. eval() / Dynamic Code | A05:2025 - Injection |
| 4d. Prototype Pollution | A05:2025 - Injection |
| 4e. Open Redirect | A01:2025 - Broken Access Control |
| 4f. CSRF | A01:2025 - Broken Access Control |
| 4g. IDOR | A01:2025 - Broken Access Control |
| 5a. Security Headers | A02:2025 - Security Misconfiguration |
| 5b. CORS | A02:2025 - Security Misconfiguration |
| 5c. Env Variable Exposure | A02:2025 - Security Misconfiguration |
| 5d. Source Maps in Production | A02:2025 - Security Misconfiguration |
| 5e. CSP vs Inline Scripts | A02:2025 - Security Misconfiguration |
| 6. Exception Handling (new, below) | A10:2025 - Mishandling of Exceptional Conditions |
| — no equivalent section yet | A06:2025 - Insecure Design *(assess by reading the flow, not greppable)* |
| — no equivalent section yet | A09:2025 - Security Logging & Alerting Failures *(check client errors are actually reported server-side, not just console.error'd)* |

---

## 1. SECRETS & CREDENTIALS

**Files to check:** `.env`, `.env.local`, `.env.production`, `next.config.*`, `vite.config.*`, any `*.ts` / `*.js` file.

**Look for:**

- `REACT_APP_` or `NEXT_PUBLIC_` prefixed vars that expose secrets (these are bundled into client JS)
- Hardcoded API keys in source: `const apiKey = "sk-..."`, `Authorization: "Bearer abc123"`
- Secrets in `localStorage` / `sessionStorage` (accessible to any JS on page)
- Secrets in Redux store or React context (can be read via DevTools)
- `.env` files committed to git (check `.gitignore`)

**Rule of thumb:** Anything in `NEXT_PUBLIC_*` is PUBLIC. Real secrets must stay server-side only.

```typescript
// BAD — secret exposed to client bundle
const STRIPE_SECRET = process.env.NEXT_PUBLIC_STRIPE_SECRET_KEY;

// GOOD — server-only (Next.js App Router)
// In a Server Component or API Route:
const STRIPE_SECRET = process.env.STRIPE_SECRET_KEY; // no NEXT_PUBLIC_ prefix
```

---

## 2. DEPENDENCIES & SUPPLY CHAIN

**Files to check:** `package.json`, `package-lock.json`, `yarn.lock`, `.npmrc`

**Look for:**

- `npm audit` equivalent — check versions against known CVEs:
  - `lodash` < 4.17.21 (prototype pollution)
  - `axios` < 1.6.0 (SSRF, CSRF bypass)
  - `next` — check against Next.js security advisories (CVE-2025-29927 path traversal in headers was major)
  - `react-scripts` — should be on latest CRA or migrated off
  - `serialize-javascript` < 6.0.0 (XSS)
  - `json5` < 2.2.2 (prototype pollution)
- Wildcard versions: `"lodash": "*"` or `">=1.0.0"`
- `.npmrc` with `registry=` pointing to untrusted registries
- Packages with names similar to popular ones (typosquatting): `reacts`, `next-js`, `axio`

**2025-specific supply chain checks (beyond "is it outdated"):**

- CI workflow (`.github/workflows/*.yml`) pins third-party actions to a SHA or version tag, never `@main`/`@master`
- `package-lock.json`/`yarn.lock`/`pnpm-lock.yaml` is committed and not gitignored — no floating installs in CI
- No `postinstall` scripts pulled from untrusted/newly-published packages (a common supply-chain attack vector)
- `npm ci` (not `npm install`) used in CI/build to enforce the lockfile exactly

---

## 3. AUTHENTICATION & AUTHORISATION

**Files to check:** Auth config files, route guards, middleware, `_middleware.ts`, `auth.ts`.

### 3a. Client-Side Auth Checks (Never Trust the Client)

```typescript
// BAD — auth check only in component, bypassable
function AdminPage() {
  const { user } = useAuth();
  if (!user?.isAdmin) return <Redirect to="/" />;
  return <SensitiveData />;
}

// GOOD — enforce on server (Next.js App Router)
// app/admin/page.tsx
import { auth } from "@/lib/auth";
import { redirect } from "next/navigation";

export default async function AdminPage() {
  const session = await auth();
  if (!session?.user?.isAdmin) redirect("/");
  return <SensitiveData />;
}
```

### 3b. JWT in localStorage vs httpOnly Cookies

```typescript
// BAD — JWT in localStorage (accessible to XSS)
localStorage.setItem("token", jwtToken);

// GOOD — httpOnly cookie (server-set, JS-inaccessible)
// Set via API response header:
// Set-Cookie: token=xxx; HttpOnly; Secure; SameSite=Strict
```

### 3c. Next.js Middleware Auth

```typescript
// Check middleware.ts — does it actually protect routes?
export function middleware(request: NextRequest) {
  const token = request.cookies.get("token");
  if (!token) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  // BAD: only checks existence, not validity
  // GOOD: verify token signature here or in the edge function
}
```

### 3d. Next.js Route Handler Auth (App Router)

```typescript
// BAD — no auth check in API route
export async function GET(req: Request) {
  const data = await db.sensitiveData.findMany();
  return Response.json(data);
}

// GOOD
export async function GET(req: Request) {
  const session = await auth();
  if (!session) return new Response("Unauthorized", { status: 401 });
  const data = await db.sensitiveData.findMany({ where: { userId: session.user.id } });
  return Response.json(data);
}
```

---

## 4. OWASP TOP 10

### 4a. XSS — dangerouslySetInnerHTML

```tsx
// BAD — injects raw HTML (XSS if userContent is attacker-controlled)
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// GOOD — sanitise before rendering
import DOMPurify from "dompurify";
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />

// BEST — avoid dangerouslySetInnerHTML entirely; use a markdown renderer with sanitisation
```

### 4b. XSS — href Injection

```tsx
// BAD — javascript: protocol injection
<a href={userProvidedUrl}>Click me</a>
// Attacker sets userProvidedUrl = "javascript:alert(document.cookie)"

// GOOD — validate protocol
const safeUrl = userProvidedUrl.startsWith("https://") ? userProvidedUrl : "#";
<a href={safeUrl}>Click me</a>
```

### 4c. eval() and Dynamic Code Execution

```typescript
// BAD
eval(userInput);
new Function(userInput)();
setTimeout(userInput, 100);

// These are always dangerous — look for any occurrence in the codebase
```

### 4d. Prototype Pollution

```typescript
// BAD — merging user-controlled object without sanitisation
function merge(target: any, source: any) {
  for (const key of Object.keys(source)) {
    target[key] = source[key]; // if source has __proto__ key, pollutes Object prototype
  }
}

// GOOD — use libraries with known-safe merge (lodash >=4.17.21 with cloneDeep)
// or validate keys: if (key === '__proto__' || key === 'constructor') continue;
```

### 4e. Open Redirect

```typescript
// BAD — redirect to user-controlled URL after login
const callbackUrl = searchParams.get("callbackUrl");
router.push(callbackUrl); // attacker sets to https://evil.com

// GOOD — validate it's a relative path
const safe = callbackUrl?.startsWith("/") ? callbackUrl : "/dashboard";
router.push(safe);
```

### 4f. CSRF in Next.js API Routes

```typescript
// Next.js App Router: SameSite cookies provide some protection
// but check: are cookies set with SameSite=Strict or Lax?
// For sensitive mutations, add explicit CSRF token validation

// Check next.config.js for:
// - allowedOrigins in server actions config
// - custom CSRF middleware
```

### 4g. Insecure Direct Object References (IDOR)

```typescript
// BAD — API route fetches by ID without ownership check
export async function GET(req: Request, { params }: { params: { id: string } }) {
  const doc = await db.documents.findUnique({ where: { id: params.id } });
  return Response.json(doc);
}

// GOOD
export async function GET(req: Request, { params }: { params: { id: string } }) {
  const session = await auth();
  const doc = await db.documents.findFirst({
    where: { id: params.id, userId: session?.user?.id }
  });
  if (!doc) return new Response("Not found", { status: 404 });
  return Response.json(doc);
}
```

---

## 5. INFRASTRUCTURE

### 5a. Security Headers (Next.js)

```typescript
// next.config.ts — check for security headers
const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  {
    key: "Content-Security-Policy",
    value: "default-src 'self'; script-src 'self'; object-src 'none';"
  },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
];

// If these are missing from next.config headers(), flag as Medium.
```

### 5b. CORS in API Routes

```typescript
// BAD — wildcard CORS
export async function OPTIONS() {
  return new Response(null, {
    headers: { "Access-Control-Allow-Origin": "*" } // too permissive
  });
}

// GOOD
const allowedOrigins = ["https://app.yourdomain.com"];
export async function OPTIONS(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  const corsOrigin = allowedOrigins.includes(origin) ? origin : allowedOrigins[0];
  return new Response(null, {
    headers: { "Access-Control-Allow-Origin": corsOrigin }
  });
}
```

### 5c. Environment Variable Exposure

```typescript
// next.config.ts — check env block
module.exports = {
  env: {
    SECRET_KEY: process.env.SECRET_KEY, // BAD — exposes to client bundle
  }
};

// GOOD — only expose what's needed client-side via NEXT_PUBLIC_ prefix,
// keep everything else server-side only
```

### 5d. Source Maps in Production

```typescript
// next.config.ts
module.exports = {
  productionBrowserSourceMaps: true, // BAD — exposes full source to attackers
};
// Default is false in Next.js — verify it hasn't been enabled
```

### 5e. Content Security Policy vs inline scripts

```tsx
// BAD — inline event handlers break CSP
<button onclick="doSomething()">Click</button>

// BAD — inline style or script tags injected dynamically
document.head.innerHTML += '<script src="' + userUrl + '"></script>';

// GOOD — use React event handlers (no inline JS)
<button onClick={doSomething}>Click</button>
```

---

## React-Specific Patterns to Flag

| Pattern | Risk | Severity |
| --------- | ------ | ---------- |
| `dangerouslySetInnerHTML` without DOMPurify | XSS | High |
| `eval()` / `new Function()` | RCE/XSS | Critical |
| JWT in `localStorage` | Token theft via XSS | High |
| Auth check only in component render | Auth bypass | High |
| User URL in `<a href>` | XSS via `javascript:` | High |
| `NEXT_PUBLIC_` prefix on real secrets | Credential exposure | Critical |
| Missing server-side auth in API routes | Broken access control | Critical |
| `productionBrowserSourceMaps: true` | Source disclosure | Medium |
| Missing security headers in `next.config` | Multiple | Medium |
| Wildcard CORS | CSRF/data theft | High |

---

## 6. EXCEPTION HANDLING & FAIL-STATES (A10:2025)

**Files to check:** API routes, `error.tsx`/error boundaries, data-fetching hooks, middleware.

**Look for:**

- Empty or swallowing `catch` blocks around auth/access-control logic
- API routes that catch an error and return a `200` with empty/default data instead of a proper error status (masks failures as success client-side)
- Error boundaries that fail open — e.g. rendering the protected content anyway if a permission check throws
- `fetch`/axios calls with no timeout, in a retry loop with no bound

```typescript
// BAD — swallows the error, response looks successful
export async function GET(req: Request) {
  try {
    const session = await auth();
    const data = await db.sensitiveData.findMany({ where: { userId: session!.user.id } });
    return Response.json(data);
  } catch {
    return Response.json([]); // looks like "no data" instead of "auth failed" — hides the real state
  }
}

// BAD — fail-open permission check
try {
  const canView = await checkPermission(user, resource);
  if (!canView) throw new Error("Forbidden");
} catch {
  // swallowed — component renders SensitiveData regardless
}
return <SensitiveData />;

// GOOD — fail closed, surface the real error
export async function GET(req: Request) {
  const session = await auth();
  if (!session) return new Response("Unauthorized", { status: 401 });
  try {
    const data = await db.sensitiveData.findMany({ where: { userId: session.user.id } });
    return Response.json(data);
  } catch (err) {
    console.error(err); // and report to a real error-tracking service, not just console
    return new Response("Internal error", { status: 500 });
  }
}
```
