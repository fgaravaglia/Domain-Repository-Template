# .NET Security Audit Checklist

Reference file for `security-auditor` skill. Load when stack is .NET (ASP.NET Core, Blazor, .NET 6+).

## OWASP Top 10:2025 Category Mapping

This file predates the 2025 taxonomy and is organised by practical bucket, not by category number.
Use this table when the report needs the `A0X:2025` tag per finding:

| Section below | OWASP 2025 Category |
| --- | --- |
| 1. Secrets & Credentials | A04:2025 - Cryptographic Failures |
| 2. Dependencies & Supply Chain | A03:2025 - Software Supply Chain Failures |
| 3a. Password Handling | A04:2025 - Cryptographic Failures |
| 3b. Missing [Authorize] | A01:2025 - Broken Access Control |
| 3c. JWT Configuration | A07:2025 - Authentication Failures |
| 3d. IDOR / Privilege Escalation | A01:2025 - Broken Access Control |
| 4a. SQL Injection | A05:2025 - Injection |
| 4b. XSS | A05:2025 - Injection |
| 4c. CSRF | A01:2025 - Broken Access Control |
| 4d. XXE | A05:2025 - Injection |
| 4e. Insecure Deserialisation | A08:2025 - Software or Data Integrity Failures |
| 4f. SSRF | A01:2025 - Broken Access Control (SSRF folded in for 2025) |
| 5a. CORS | A02:2025 - Security Misconfiguration |
| 5b. Security Headers | A02:2025 - Security Misconfiguration |
| 5c. Verbose Error Messages | A02:2025 - Security Misconfiguration |
| 5d. File Upload | A01:2025 - Broken Access Control |
| 6. Exception Handling (new, below) | A10:2025 - Mishandling of Exceptional Conditions |
| — no equivalent section yet | A06:2025 - Insecure Design *(assess by reading the flow, not greppable)* |
| — no equivalent section yet | A09:2025 - Security Logging & Alerting Failures *(check auth/access-control logging + alerting exists)* |

---

## 1. SECRETS & CREDENTIALS

**Files to check:** `appsettings*.json`, `appsettings.Development.json`, `secrets.json`, `.env`, `*.config`, comments in any C# file, test files.

**Look for:**

- Hardcoded connection strings with passwords: `Password=`, `pwd=`, `User ID=`
- Hardcoded API keys / tokens: `ApiKey = "..."`, `Bearer ey...`
- Private keys or certificates embedded in source
- Credentials in XML config: `<add key="ApiKey" value="abc123"/>`
- Secrets committed to git (check `.gitignore` — is `appsettings.Development.json` excluded?)
- Secrets appearing in `ILogger` calls: `_logger.LogInformation($"Key: {apiKey}")`

**Safe pattern:**

```csharp
// Good: read from environment or Secret Manager
var key = builder.Configuration["ExternalApi:Key"]; // via Azure Key Vault / env var
```

---

## 2. DEPENDENCIES & SUPPLY CHAIN

**Files to check:** `*.csproj`, `packages.config`, `Directory.Packages.props`

**Look for:**

- Packages without version pins or with wildcard versions (`*`, `>=`)
- Packages not updated in 12+ months (check NuGet for last publish date)
- Known vulnerable packages — common offenders:
  - `Newtonsoft.Json` < 13.0.1 (ReDoS)
  - `System.Text.Encodings.Web` < 4.5.1 (XSS bypass)
  - `Microsoft.AspNetCore.*` below current LTS
  - `IdentityModel` / `System.IdentityModel.Tokens.Jwt` old versions
- `BinaryFormatter` usage anywhere (deprecated + dangerous)

**Equivalent of `dotnet list package --vulnerable`:**
Cross-reference package names + versions against [OSV.dev](https://osv.dev) or NVD patterns.

**2025-specific supply chain checks (beyond "is it outdated"):**

- CI/CD pipeline (Azure DevOps YAML / GitHub Actions) pulls tasks/actions pinned to a version or SHA, not `@main`/`latest`
- `Directory.Packages.props` / central package management in use where the repo is large enough to warrant it — no per-project version drift
- NuGet package source is the official feed only; no `<add key="..." value="http://...">` pointing at an internal/unverified feed without integrity checks
- Signed packages / package source mapping (`packageSourceMapping` in `NuGet.Config`) enabled where feasible

---

## 3. AUTHENTICATION & AUTHORISATION

**Files to check:** `Program.cs`, `Startup.cs`, controllers, middleware, identity config.

### 3a. Password Handling

```csharp
// BAD — plain MD5
var hash = MD5.HashData(Encoding.UTF8.GetBytes(password));

// BAD — SHA1
var hash = SHA1.HashData(Encoding.UTF8.GetBytes(password));

// GOOD
var hasher = new PasswordHasher<ApplicationUser>();
var hashed = hasher.HashPassword(user, plainPassword);
```

### 3b. Missing [Authorize] Attributes

- Check every controller and action that handles sensitive data
- Look for `[AllowAnonymous]` on endpoints that shouldn't be public
- Check route-level auth vs action-level auth gaps

### 3c. JWT Configuration

```csharp
// BAD — weak secret
options.TokenValidationParameters = new TokenValidationParameters
{
    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("secret")), // too short
    ValidateLifetime = false, // never do this
};

// BAD — alg=none bypass possible if ValidateIssuerSigningKey = false

// GOOD
options.TokenValidationParameters = new TokenValidationParameters
{
    ValidateIssuerSigningKey = true,
    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"])), // 256-bit min
    ValidateLifetime = true,
    ClockSkew = TimeSpan.Zero,
    ValidateAudience = true,
    ValidateIssuer = true,
};
```

### 3d. IDOR / Privilege Escalation

- Look for endpoints that take user/resource IDs from the request body without validating ownership:

```csharp
// BAD — user can change any order
[HttpGet("/orders/{id}")]
public async Task<Order> GetOrder(int id) => await _db.Orders.FindAsync(id);

// GOOD — scope to current user
[HttpGet("/orders/{id}")]
public async Task<Order> GetOrder(int id)
{
    var userId = User.GetUserId();
    return await _db.Orders.FirstOrDefaultAsync(o => o.Id == id && o.UserId == userId);
}
```

---

## 4. OWASP TOP 10

### 4a. SQL Injection

```csharp
// BAD — raw string interpolation
var result = await _db.Database.ExecuteSqlRawAsync(
    $"SELECT * FROM Users WHERE Email = '{email}'");

// GOOD — parameterised
var result = await _db.Users.Where(u => u.Email == email).ToListAsync(); // EF
// or
var result = await _db.Database.ExecuteSqlRawAsync(
    "SELECT * FROM Users WHERE Email = {0}", email);
```

### 4b. XSS

```csharp
// BAD — raw HTML injection in Razor
@Html.Raw(userInput)

// GOOD — auto-encoded (default in Razor)
@userInput

// For manual encoding:
var encoded = HtmlEncoder.Default.Encode(userInput);
```

### 4c. CSRF

```csharp
// BAD — no anti-forgery on state-changing endpoint
[HttpPost]
public IActionResult Update(UpdateModel model) { ... }

// GOOD
[HttpPost]
[ValidateAntiForgeryToken]
public IActionResult Update(UpdateModel model) { ... }

// Or globally in Program.cs:
builder.Services.AddControllersWithViews(options =>
    options.Filters.Add(new AutoValidateAntiforgeryTokenAttribute()));
```

### 4d. XXE (XML External Entity)

```csharp
// BAD — default XmlReader allows external entities
var reader = XmlReader.Create(inputStream);

// GOOD — disable external entities
var settings = new XmlReaderSettings
{
    DtdProcessing = DtdProcessing.Prohibit,
    XmlResolver = null
};
var reader = XmlReader.Create(inputStream, settings);
```

### 4e. Insecure Deserialisation

```csharp
// BAD — TypeNameHandling enables arbitrary type instantiation (RCE risk)
var obj = JsonConvert.DeserializeObject(json, new JsonSerializerSettings
{
    TypeNameHandling = TypeNameHandling.All // CRITICAL vulnerability
});

// BAD — BinaryFormatter (RCE)
var formatter = new BinaryFormatter();
var obj = formatter.Deserialize(stream);

// GOOD — System.Text.Json (safe by default) or whitelist types
var obj = JsonSerializer.Deserialize<MyExpectedType>(json);
```

### 4f. SSRF

```csharp
// BAD — user-controlled URL passed to HttpClient
var response = await _httpClient.GetAsync(userProvidedUrl);

// GOOD — validate against allowlist
var allowed = new[] { "https://api.trusted.com", "https://data.partner.com" };
if (!allowed.Any(a => userProvidedUrl.StartsWith(a)))
    throw new ArgumentException("URL not allowed");
```

---

## 5. INFRASTRUCTURE

### 5a. CORS

```csharp
// BAD — wildcard origin with credentials
app.UseCors(policy => policy
    .AllowAnyOrigin()
    .AllowCredentials()); // This throws at runtime but watch for AllowAnyOrigin + specific methods

// BAD — reflect origin without validation
.WithOrigins(Request.Headers["Origin"]) // never do this

// GOOD
app.UseCors(policy => policy
    .WithOrigins("https://app.yourdomain.com")
    .AllowCredentials()
    .WithMethods("GET", "POST"));
```

### 5b. Security Headers

```csharp
// Check Program.cs for:
app.UseHsts();            // HSTS — missing = HTTP downgrade attacks
app.UseHttpsRedirection(); // Missing = plain HTTP traffic

// Check for missing headers middleware:
// Content-Security-Policy, X-Frame-Options, X-Content-Type-Options, Referrer-Policy
// These are NOT added by default in ASP.NET Core — must be explicit.

// Example via middleware:
app.Use(async (context, next) =>
{
    context.Response.Headers.Add("X-Frame-Options", "DENY");
    context.Response.Headers.Add("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Add("Referrer-Policy", "strict-origin-when-cross-origin");
    await next();
});
```

### 5c. Verbose Error Messages

```csharp
// BAD in production — exposes stack traces
if (app.Environment.IsDevelopment())
    app.UseDeveloperExceptionPage();
// But check: is this gated properly? Is ASPNETCORE_ENVIRONMENT set correctly in prod?

// GOOD
app.UseExceptionHandler("/Error");
```

### 5d. File Upload

```csharp
// BAD — no validation
[HttpPost]
public async Task<IActionResult> Upload(IFormFile file)
{
    var path = Path.Combine("uploads", file.FileName); // path traversal risk
    using var stream = System.IO.File.Create(path);
    await file.CopyToAsync(stream);
}

// GOOD
private static readonly string[] AllowedExtensions = { ".pdf", ".png", ".jpg" };
private const long MaxFileSize = 10 * 1024 * 1024; // 10 MB

[HttpPost]
public async Task<IActionResult> Upload(IFormFile file)
{
    if (file.Length > MaxFileSize) return BadRequest("File too large");
    var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
    if (!AllowedExtensions.Contains(ext)) return BadRequest("File type not allowed");
    var safeName = Path.GetRandomFileName() + ext; // no user-controlled filename
    var path = Path.Combine(_uploadPath, safeName);
    using var stream = System.IO.File.Create(path);
    await file.CopyToAsync(stream);
}
```

---

## 6. EXCEPTION HANDLING & FAIL-STATES (A10:2025)

**Files to check:** anything with `try`/`catch` around auth, access-control, or external-service calls; global exception middleware in `Program.cs`.

**Look for:**

- Empty or swallowing catch blocks around security-relevant code
- External service failures (identity provider, payment gateway) defaulting to "allow" instead of "deny"
- Unbounded retry/timeout on outbound `HttpClient` calls (self-inflicted DoS risk, and a fail-open surface if a retry loop eventually gives up and lets the request through unauthenticated)

```csharp
// BAD — swallows the exception, request proceeds as if auth succeeded
try
{
    await _identityService.ValidateAsync(token);
}
catch (Exception)
{
    // nothing here — silently continues
}

// BAD — fail-open on external dependency
try
{
    return await _authProvider.CheckAsync(token);
}
catch (HttpRequestException)
{
    return true; // auth provider down -> let everyone in
}

// GOOD — fail closed, log, and surface a clear error
try
{
    return await _authProvider.CheckAsync(token);
}
catch (HttpRequestException ex)
{
    _logger.LogError(ex, "Auth provider unreachable — denying by default");
    throw new ServiceUnavailableException("Authentication service unavailable");
}

// Also check: HttpClient instances have an explicit Timeout set, and Polly retry
// policies (if used) have a bounded retry count, not an infinite loop.
```
