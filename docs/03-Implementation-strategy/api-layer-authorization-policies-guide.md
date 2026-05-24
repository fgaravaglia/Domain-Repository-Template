# Policy di Autorizzazione .NET - Linee Guida per AI Code Assistant

## Obiettivo
Implementare un sistema di autorizzazione basato su Policy in applicazioni .NET, seguendo il pattern a 3 layer: Policy Definition → Requirement + Handler → Controller Decoration.

## Principi Architetturali

### 1. Separazione delle Responsabilità
- **Policy**: definisce il "cosa" (nome simbolico della regola)
- **Requirement**: contratto dell'autorizzazione (interfaccia)
- **Handler**: logica di business del "come verificare"
- **Controller**: applica la policy tramite attributo `[Authorize]`

### 2. Regole di Composizione
- Una policy può combinare più requirement
- Un requirement può avere più handler (valutati in OR)
- Gli handler ricevono dipendenze via DI (repository, servizi, HttpContext)

### 3. Policy Parametriche vs Policy Statiche

**PROBLEMA CRITICO**: Rischio esplosione di policy identiche per ogni permesso.

#### ❌ ANTI-PATTERN: Policy per ogni permesso
```csharp
// SBAGLIATO: 50+ policy quasi identiche
options.AddPolicy("CanReadBoard", policy => 
    policy.RequireClaim("permission", "read:board"));
options.AddPolicy("CanWriteBoard", policy => 
    policy.RequireClaim("permission", "write:board"));
options.AddPolicy("CanDeleteBoard", policy => 
    policy.RequireClaim("permission", "delete:board"));
// ... codice ripetitivo insostenibile
```

#### ✅ SOLUZIONE: Policy Provider Dinamico

**Quando usare policy dinamiche:**
- Autorizzazioni basate su claim semplici (es. `permission:read:board`)
- Pattern ripetitivo su decine di endpoint
- Sistema di permessi configurabile (OAuth scopes, ACL)

**Quando usare policy statiche:**
- Logica multi-requirement (ruolo + claim + stato risorsa)
- Resource-based authorization (ownership, gerarchia)
- Regole di business complesse con handler custom

#### Decision Tree

```
Il permesso è solo verifica di un claim?
├─ SÌ → Policy Provider Dinamico (vedi Approccio A)
└─ NO → Dipende da cosa?
    ├─ Combinazione Ruolo + Claim → Policy statica composita
    ├─ Ownership risorsa → Custom Requirement + Handler (Approccio B)
    └─ Logica business (DB, API) → Custom Requirement + Handler
```

---

## Template di Implementazione

### OPZIONE 1: Policy Dinamiche (Permessi Semplici)

**Scenario**: Hai 20+ endpoint con permessi tipo `read:X`, `write:X`, `delete:X`.

#### Step 1: Authorization Policy Provider Custom

```csharp
// File: Authorization/PermissionPolicyProvider.cs
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;

namespace YourApp.Authorization;

/// <summary>
/// Genera policy dinamicamente dal nome, evitando esplosione di policy statiche.
/// Supporta pattern: RequirePermission:{permissionName}
/// </summary>
public class PermissionPolicyProvider : IAuthorizationPolicyProvider
{
    private const string PermissionPrefix = "RequirePermission:";
    private readonly DefaultAuthorizationPolicyProvider _fallbackProvider;

    public PermissionPolicyProvider(IOptions<AuthorizationOptions> options)
    {
        // Fallback per policy statiche (es. custom requirement)
        _fallbackProvider = new DefaultAuthorizationPolicyProvider(options);
    }

    public Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        // Se policy inizia con prefix, generala dinamicamente
        if (policyName.StartsWith(PermissionPrefix, StringComparison.OrdinalIgnoreCase))
        {
            var permission = policyName.Substring(PermissionPrefix.Length);
            
            var policy = new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser()
                .RequireClaim("permission", permission)
                .Build();
            
            return Task.FromResult<AuthorizationPolicy?>(policy);
        }

        // Altrimenti usa policy statiche registrate
        return _fallbackProvider.GetPolicyAsync(policyName);
    }

    public Task<AuthorizationPolicy> GetDefaultPolicyAsync() => 
        _fallbackProvider.GetDefaultPolicyAsync();

    public Task<AuthorizationPolicy?> GetFallbackPolicyAsync() => 
        _fallbackProvider.GetFallbackPolicyAsync();
}
```

#### Step 2: Attributo Custom per Sintassi Pulita

```csharp
// File: Authorization/RequirePermissionAttribute.cs
using Microsoft.AspNetCore.Authorization;

namespace YourApp.Authorization;

/// <summary>
/// Verifica che l'utente abbia il claim 'permission' con valore specificato.
/// Usa: [RequirePermission("read:board")] invece di [Authorize(Policy = "...")]
/// </summary>
public class RequirePermissionAttribute : AuthorizeAttribute
{
    public RequirePermissionAttribute(string permission)
    {
        // Delega a PermissionPolicyProvider tramite naming convention
        Policy = $"RequirePermission:{permission}";
    }
}
```

#### Step 3: Registrazione (Program.cs)

```csharp
// IMPORTANTE: registra PRIMA di AddControllers()
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();

builder.Services.AddAuthorization(options =>
{
    // Qui registri SOLO policy statiche complesse
    options.AddPolicy("CanApproveDeal", policy =>
    {
        policy.RequireClaim("permission", "approve:deal");
        policy.RequireClaim("seniority", "Senior", "Lead");
        policy.Requirements.Add(new DealAmountLimitRequirement(1_000_000));
    });
});
```

#### Step 4: Uso nei Controller

```csharp
[ApiController]
[Route("api/boards")]
public class BoardsController : ControllerBase
{
    // Policy generata dinamicamente - zero configurazione
    [HttpGet("{id}")]
    [RequirePermission("read:board")]
    public IActionResult GetBoard(string id) { }

    [HttpPost]
    [RequirePermission("write:board")]
    public IActionResult CreateBoard(BoardDto dto) { }

    [HttpDelete("{id}")]
    [RequirePermission("delete:board")]
    public IActionResult DeleteBoard(string id) { }

    // Mix: policy statica per logica complessa
    [HttpPost("{id}/approve")]
    [Authorize(Policy = "CanApproveDeal")]
    public IActionResult ApproveDeal(string id) { }
}
```

**Vantaggi:**
- **Zero boilerplate**: aggiungi 100 endpoint senza toccare Program.cs
- **Convention over configuration**: naming pattern `permission:{action}:{resource}`
- **Manutenibilità**: cambi logica in un punto solo (PermissionPolicyProvider)

---

### OPZIONE 2: Policy Statiche (Logica Complessa)

### OPZIONE 2: Policy Statiche (Logica Complessa)

**Scenario**: Autorizzazione dipende da ownership risorsa, combinazione ruoli, o logica business.

### STEP 1: Registrazione Policy (Program.cs / Startup.cs)

```csharp
// Posizione: dopo AddAuthentication(), prima di AddControllers()
builder.Services.AddAuthorization(options =>
{
    // Pattern 1: Policy basata su ruolo/claim semplice
    options.AddPolicy("RequireAdminRole", policy => 
        policy.RequireRole("Admin"));
    
    options.AddPolicy("RequireEmailVerified", policy =>
        policy.RequireClaim("email_verified", "true"));

    // Pattern 2: Policy con custom requirement (logica complessa)
    options.AddPolicy("CanModifyResource", policy =>
        policy.Requirements.Add(new ResourceOwnershipRequirement()));
    
    // Pattern 3: Policy composita
    options.AddPolicy("SeniorTrader", policy =>
    {
        policy.RequireRole("Trader");
        policy.RequireClaim("seniority_level", "Senior", "Lead");
        policy.Requirements.Add(new MinimumTenureRequirement(yearsRequired: 3));
    });
});
```

**Naming convention**: 
- Verbi per azioni: `CanModify`, `CanView`, `CanDelete`
- Sostantivi per stati: `RequireAdminRole`, `IsEmailVerified`

---

### STEP 2: Custom Requirement (file separato: Requirements/XxxRequirement.cs)

```csharp
using Microsoft.AspNetCore.Authorization;

namespace YourApp.Authorization.Requirements;

/// <summary>
/// Verifica che l'utente sia proprietario della risorsa richiesta.
/// Usato per operazioni di modifica/cancellazione.
/// </summary>
public class ResourceOwnershipRequirement : IAuthorizationRequirement
{
    // Opzionale: parametri di configurazione
    public bool AllowAdminOverride { get; init; } = true;
}
```

**Quando creare un Requirement:**
- Logica che dipende da stato esterno (DB, API)
- Regole che combinano User claims + risorsa specifica
- Autorizzazioni configurabili (es. flag da appsettings)

---

### STEP 3: Authorization Handler (file separato: Handlers/XxxHandler.cs)

```csharp
using Microsoft.AspNetCore.Authorization;
using YourApp.Data;

namespace YourApp.Authorization.Handlers;

public class ResourceOwnershipHandler 
    : AuthorizationHandler<ResourceOwnershipRequirement>
{
    private readonly IResourceRepository _repo;
    private readonly ILogger<ResourceOwnershipHandler> _logger;

    public ResourceOwnershipHandler(
        IResourceRepository repo, 
        ILogger<ResourceOwnershipHandler> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ResourceOwnershipRequirement requirement)
    {
        // 1. Estrai identificatore utente
        var userId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
        {
            _logger.LogWarning("User ID claim non trovato");
            return; // Fail silenzioso: non chiamare context.Fail()
        }

        // 2. Recupera risorsa dal context (passata manualmente, vedi nota sotto)
        if (context.Resource is not HttpContext httpContext)
            return;

        var resourceId = httpContext.GetRouteValue("id")?.ToString();
        if (string.IsNullOrEmpty(resourceId))
            return;

        // 3. Logica di business
        var resource = await _repo.GetByIdAsync(resourceId);
        if (resource == null)
            return;

        // 4. Valutazione
        if (resource.OwnerId == userId)
        {
            context.Succeed(requirement);
            return;
        }

        // Override per admin (se configurato nel requirement)
        if (requirement.AllowAdminOverride && 
            context.User.IsInRole("Admin"))
        {
            _logger.LogInformation(
                "Admin override applicato per risorsa {ResourceId}", 
                resourceId);
            context.Succeed(requirement);
        }

        // NON chiamare context.Fail() a meno di voler bloccare altri handler
    }
}
```

**Registrazione handler** (Program.cs):
```csharp
builder.Services.AddScoped<IAuthorizationHandler, ResourceOwnershipHandler>();
```

**Regole critiche:**
- `context.Succeed(requirement)`: autorizzazione concessa
- `return` senza chiamare nulla: handler neutro (lascia decidere altri)
- `context.Fail()`: blocca TUTTI gli altri handler (usare raramente)

---

### STEP 4: Decorazione Controller

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace YourApp.Controllers;

[ApiController]
[Route("api/resources")]
[Authorize] // Policy di default: richiede autenticazione
public class ResourcesController : ControllerBase
{
    // Policy a livello di singola action
    [HttpGet]
    [Authorize(Policy = "RequireEmailVerified")]
    public async Task<IActionResult> GetAll()
    {
        // ...
    }

    [HttpPut("{id}")]
    [Authorize(Policy = "CanModifyResource")]
    public async Task<IActionResult> Update(string id, ResourceDto dto)
    {
        // Se arrivi qui, la policy è passata
        // ...
    }

    // Combinazione di policy (AND logico)
    [HttpDelete("{id}")]
    [Authorize(Policy = "CanModifyResource")]
    [Authorize(Policy = "RequireAdminRole")]
    public async Task<IActionResult> Delete(string id)
    {
        // Entrambe le policy devono passare
        // ...
    }
}
```

**Pattern avanzato: policy inline (scenari one-off)**
```csharp
[HttpPost("promote")]
[Authorize(Roles = "Admin,SuperUser")] // Shortcut per policy semplice
public IActionResult PromoteUser(string userId) { }
```

---

## Gestione Resource-Based Authorization

**Problema**: alcuni handler necessitano della risorsa specifica (es. `dealId`).

### Opzione A: Estrazione da Route (usata nell'esempio sopra)
```csharp
var resourceId = httpContext.GetRouteValue("id")?.ToString();
```

### Opzione B: Autorizzazione Imperativa (quando serve logica nel controller)
```csharp
[HttpPut("{id}")]
public async Task<IActionResult> Update(
    string id, 
    ResourceDto dto,
    [FromServices] IAuthorizationService authService)
{
    var resource = await _repo.GetByIdAsync(id);
    
    var authResult = await authService.AuthorizeAsync(
        User, 
        resource, // Passi l'oggetto risorsa
        "CanModifyResource");

    if (!authResult.Succeeded)
        return Forbid();

    // Continua con l'update
}
```

**Quando usare B:**
- Necessiti della risorsa completa (non solo ID)
- Logica di autorizzazione dipende da stato mutevole della risorsa
- Vuoi messaggi di errore personalizzati

**Trade-off**: B bypassa il decoratore `[Authorize]` → documentalo come scelta architetturale.

---

## Testing

### Test Policy Provider (Unit)

```csharp
public class PermissionPolicyProviderTests
{
    [Fact]
    public async Task GetPolicyAsync_ValidPermission_GeneratesPolicy()
    {
        // Arrange
        var options = Options.Create(new AuthorizationOptions());
        var provider = new PermissionPolicyProvider(options);

        // Act
        var policy = await provider.GetPolicyAsync("RequirePermission:read:board");

        // Assert
        Assert.NotNull(policy);
        Assert.Contains(policy.Requirements, 
            r => r is ClaimsAuthorizationRequirement claim && 
                 claim.ClaimType == "permission" && 
                 claim.AllowedValues.Contains("read:board"));
    }

    [Fact]
    public async Task GetPolicyAsync_StaticPolicy_FallsBackToDefault()
    {
        // Arrange
        var options = Options.Create(new AuthorizationOptions());
        options.Value.AddPolicy("CustomPolicy", p => p.RequireRole("Admin"));
        var provider = new PermissionPolicyProvider(options);

        // Act
        var policy = await provider.GetPolicyAsync("CustomPolicy");

        // Assert
        Assert.NotNull(policy);
        Assert.Contains(policy.Requirements, r => r is RolesAuthorizationRequirement);
    }
}
```

### Test Handler (Unit)
```csharp
public class ResourceOwnershipHandlerTests
{
    [Fact]
    public async Task HandleRequirementAsync_OwnerUser_Succeeds()
    {
        // Arrange
        var repo = new Mock<IResourceRepository>();
        repo.Setup(r => r.GetByIdAsync("123"))
            .ReturnsAsync(new Resource { OwnerId = "user1" });

        var handler = new ResourceOwnershipHandler(repo.Object, Mock.Of<ILogger>());
        
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(ClaimTypes.NameIdentifier, "user1")
        }));

        var context = new AuthorizationHandlerContext(
            new[] { new ResourceOwnershipRequirement() },
            user,
            CreateHttpContext("123")); // Mock HttpContext con route value

        // Act
        await handler.HandleRequirementAsync(context, new ResourceOwnershipRequirement());

        // Assert
        Assert.True(context.HasSucceeded);
    }
}
```

### Test Integration (Controller)
```csharp
[Fact]
public async Task Update_NonOwner_Returns403()
{
    var client = _factory.CreateClient();
    client.DefaultRequestHeaders.Authorization = 
        new AuthenticationHeaderValue("Bearer", _nonOwnerToken);

    var response = await client.PutAsJsonAsync("/api/resources/123", new ResourceDto());

    Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
}
```

---

## Checklist per AI Assistant

**PRIMA DI INIZIARE: Scegli l'approccio**

- [ ] Conta policy necessarie:
  - [ ] 10+ policy simili (solo claim/ruolo diverso) → Usa PermissionPolicyProvider
  - [ ] 3-5 policy con logica custom → Usa Policy Statiche
  - [ ] Mix → Combina entrambi

**Se usi PermissionPolicyProvider (OPZIONE 1):**

- [ ] `PermissionPolicyProvider` implementa `IAuthorizationPolicyProvider`
- [ ] Gestisce fallback a `DefaultAuthorizationPolicyProvider` per policy statiche
- [ ] Attributo `RequirePermissionAttribute` usa naming convention corretta
- [ ] Provider registrato come Singleton in Program.cs
- [ ] Documentato il pattern di naming (es. `permission:{action}:{resource}`)

**Se usi Policy Statiche (OPZIONE 2):**

- [ ] Policy registrata in `AddAuthorization()` con nome semantico
- [ ] Requirement implementa `IAuthorizationRequirement` (anche se vuoto)
- [ ] Handler:
  - [ ] Eredita da `AuthorizationHandler<TRequirement>`
  - [ ] Riceve dipendenze via constructor injection
  - [ ] Usa `context.Succeed()` per autorizzare
  - [ ] NON usa `context.Fail()` a meno di necessità esplicita
  - [ ] Logga eventi significativi (override admin, risorse non trovate)
- [ ] Handler registrato come scoped/transient in DI
- [ ] Controller decorato con `[Authorize(Policy = "...")]`
- [ ] Documentati trade-off se usi autorizzazione imperativa

---

## Anti-Pattern da Evitare

### ❌ ANTI-PATTERN 1: Esplosione di Policy per Permessi Semplici
```csharp
// SBAGLIATO: 50+ policy identiche
options.AddPolicy("CanReadBoard", policy => 
    policy.RequireClaim("permission", "read:board"));
options.AddPolicy("CanWriteBoard", policy => 
    policy.RequireClaim("permission", "write:board"));
options.AddPolicy("CanReadUser", policy => 
    policy.RequireClaim("permission", "read:user"));
// ... decine di duplicati
```

### ✅ Corretto: Policy Provider Dinamico
```csharp
// Registra una volta
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();

// Usa infinite volte
[RequirePermission("read:board")]
[RequirePermission("write:board")]
[RequirePermission("read:user")]
```

---

### ❌ ANTI-PATTERN 2: Logica di autorizzazione nel controller
```csharp
// SBAGLIATO
public IActionResult Update(string id)
{
    if (!User.IsInRole("Admin") && !IsOwner(id))
        return Forbid();
    // ...
}
```

### ✅ Corretto: delega alla policy
```csharp
[Authorize(Policy = "CanModifyResource")]
public IActionResult Update(string id) { /* ... */ }
```

---

### ❌ ANTI-PATTERN 3: Policy troppo specifiche
```csharp
// SBAGLIATO: una policy per risorsa
options.AddPolicy("CanModifyDeal123", ...);
options.AddPolicy("CanModifyDeal456", ...);
```

### ✅ Corretto: policy generica + parametri
```csharp
options.AddPolicy("CanModifyDeal", policy =>
    policy.Requirements.Add(new ResourceOwnershipRequirement()));
```

---

### ❌ ANTI-PATTERN 4: Handler senza logging
```csharp
// SBAGLIATO: fallimento silenzioso senza traccia
if (resource.OwnerId != userId)
    return;
```

### ✅ Corretto: audit trail
```csharp
if (resource.OwnerId != userId)
{
    _logger.LogWarning(
        "User {UserId} tentativo accesso risorsa {ResourceId} (owner: {OwnerId})",
        userId, resourceId, resource.OwnerId);
    return;
}
```

---

## Configurazione Avanzata

### Policy Provider con Logica Composita

Per permessi che richiedono **claim + ruolo** ma restano parametrici:

```csharp
public class AdvancedPermissionPolicyProvider : IAuthorizationPolicyProvider
{
    private const string PermissionPrefix = "RequirePermission:";
    private readonly DefaultAuthorizationPolicyProvider _fallback;

    public AdvancedPermissionPolicyProvider(IOptions<AuthorizationOptions> options)
    {
        _fallback = new DefaultAuthorizationPolicyProvider(options);
    }

    public Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        if (policyName.StartsWith(PermissionPrefix))
        {
            var parts = policyName.Substring(PermissionPrefix.Length).Split(':');
            var permission = parts[0]; // es. "read"
            var resource = parts.Length > 1 ? parts[1] : null; // es. "board"

            var policyBuilder = new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser()
                .RequireClaim("permission", $"{permission}:{resource}");

            // Regola extra: write/delete richiedono ruolo Trader
            if (permission is "write" or "delete")
            {
                policyBuilder.RequireRole("Trader", "Admin");
            }

            return Task.FromResult<AuthorizationPolicy?>(policyBuilder.Build());
        }

        return _fallback.GetPolicyAsync(policyName);
    }

    // ... GetDefaultPolicyAsync, GetFallbackPolicyAsync
}

// Uso: [RequirePermission("write:board")] → verifica claim + ruolo automaticamente
```

---

### Policy con Fallback (AllowAnonymous su action specifica)
```csharp
[Authorize(Policy = "RequireLogin")] // Controller-level
public class AccountController : ControllerBase
{
    [AllowAnonymous] // Override per singola action
    [HttpPost("register")]
    public IActionResult Register() { }
}
```

### Policy da Configuration
```csharp
// appsettings.json
{
  "Authorization": {
    "MinimumTenureYears": 3
  }
}

// Program.cs
var minTenure = builder.Configuration.GetValue<int>("Authorization:MinimumTenureYears");
options.AddPolicy("SeniorEmployee", policy =>
    policy.Requirements.Add(new MinimumTenureRequirement(minTenure)));
```

---

## Domande da Risolvere Prima di Implementare

**PASSO 0: Scegli l'Approccio Corretto**

```
Conta quante policy servono per il tuo dominio:
├─ 10+ policy quasi identiche (solo claim diverso)
│   └─ Usa OPZIONE 1: PermissionPolicyProvider
│
├─ 3-5 policy con logica custom
│   └─ Usa OPZIONE 2: Policy Statiche + Requirement
│
└─ Mix (permessi semplici + logica complessa)
    └─ Combina: PermissionPolicyProvider + Policy Statiche
```

**Poi rispondi:**

1. **La regola cambierà spesso?** → Preferisci requirement custom su ruoli hard-coded
2. **Serve lo stato della risorsa?** → Usa autorizzazione imperativa o estrai da route
3. **Admin deve avere override?** → Parametrizza nel requirement
4. **Serve audit?** → Inietta `ILogger` nell'handler
5. **Devo combinare più condizioni?** → Policy composita con multipli requirement

---

## Output Atteso dall'AI

**Prima di generare codice, l'AI deve identificare lo scenario:**

1. **Assessment iniziale**: 
   - "Hai bisogno di 10+ policy simili? → Genero PermissionPolicyProvider"
   - "Hai logica complessa (ownership, business rules)? → Genero Requirement + Handler"

**Per OPZIONE 1 (Policy Dinamiche):**

1. **File PermissionPolicyProvider** con:
   - Implementazione `IAuthorizationPolicyProvider`
   - Fallback a DefaultAuthorizationPolicyProvider
   - XML doc su pattern naming supportato
2. **File RequirePermissionAttribute** con esempio d'uso
3. **Blocco registrazione** in Program.cs
4. **Test unitario** per policy generation
5. **Snippet controller** con 3+ esempi di permessi diversi

**Per OPZIONE 2 (Policy Statiche):**

1. **Blocco registrazione** (Program.cs) con commento sul perché di quella policy
2. **File Requirement** con XML doc che spiega la regola
3. **File Handler** con:
   - Dependency injection esplicita
   - Gestione errori (claim mancanti, risorsa null)
   - Logging di eventi chiave
   - Commenti sul `context.Succeed()` vs `return`
4. **Snippet decorazione controller** con esempio d'uso
5. **Test unitario** base per l'handler

---

## Esempio Completo Fine-to-End

**Scenario**: Sistema di board collaborativi con permessi CRUD + ownership.

**Strategia**: Mix di approcci
- Permessi base (read/write) → Policy Provider
- Logica complessa (ownership) → Policy Statiche

---

### 1. Infrastruttura Policy Provider

**Authorization/PermissionPolicyProvider.cs**
```csharp
namespace YourApp.Authorization;

public class PermissionPolicyProvider : IAuthorizationPolicyProvider
{
    private const string PermissionPrefix = "RequirePermission:";
    private readonly DefaultAuthorizationPolicyProvider _fallback;

    public PermissionPolicyProvider(IOptions<AuthorizationOptions> options)
    {
        _fallback = new DefaultAuthorizationPolicyProvider(options);
    }

    public Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        if (policyName.StartsWith(PermissionPrefix))
        {
            var permission = policyName.Substring(PermissionPrefix.Length);
            var policy = new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser()
                .RequireClaim("permission", permission)
                .Build();
            return Task.FromResult<AuthorizationPolicy?>(policy);
        }

        return _fallback.GetPolicyAsync(policyName);
    }

    public Task<AuthorizationPolicy> GetDefaultPolicyAsync() => 
        _fallback.GetDefaultPolicyAsync();

    public Task<AuthorizationPolicy?> GetFallbackPolicyAsync() => 
        _fallback.GetFallbackPolicyAsync();
}
```

**Authorization/RequirePermissionAttribute.cs**
```csharp
namespace YourApp.Authorization;

public class RequirePermissionAttribute : AuthorizeAttribute
{
    public RequirePermissionAttribute(string permission)
    {
        Policy = $"RequirePermission:{permission}";
    }
}
```

---

### 2. Policy Statica per Ownership

**Requirements/BoardOwnershipRequirement.cs**
```csharp
namespace YourApp.Authorization.Requirements;

/// <summary>
/// Verifica che l'utente sia il creatore del board o un collaboratore.
/// </summary>
public class BoardOwnershipRequirement : IAuthorizationRequirement { }
```

**Handlers/BoardOwnershipHandler.cs**
```csharp
namespace YourApp.Authorization.Handlers;

public class BoardOwnershipHandler : AuthorizationHandler<BoardOwnershipRequirement>
{
    private readonly IBoardRepository _repo;

    public BoardOwnershipHandler(IBoardRepository repo) => _repo = repo;

    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        BoardOwnershipRequirement requirement)
    {
        var userId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null) return;

        if (context.Resource is not HttpContext httpContext) return;
        var boardId = httpContext.GetRouteValue("id")?.ToString();
        if (boardId == null) return;

        var board = await _repo.GetByIdAsync(boardId);
        if (board == null) return;

        // Logica: creatore o collaboratore autorizzato
        if (board.CreatedBy == userId || board.Collaborators.Contains(userId))
            context.Succeed(requirement);
    }
}
```

---

### 3. Registrazione (Program.cs)

```csharp
// 1. Registra Policy Provider per permessi dinamici
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();

// 2. Registra policy statiche per logica complessa
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CanModifyBoard", policy =>
        policy.Requirements.Add(new BoardOwnershipRequirement()));
});

// 3. Registra handler
builder.Services.AddScoped<IAuthorizationHandler, BoardOwnershipHandler>();
```

---

### 4. Controller (Mix di Approcci)

```csharp
[ApiController]
[Route("api/boards")]
public class BoardsController : ControllerBase
{
    // Permessi base → Policy dinamica (zero config)
    [HttpGet]
    [RequirePermission("read:board")]
    public async Task<IActionResult> GetAll() 
    { 
        // Chiunque con claim permission:read:board
    }

    [HttpGet("{id}")]
    [RequirePermission("read:board")]
    public async Task<IActionResult> GetById(string id) 
    { 
        // Permesso base, non serve ownership
    }

    // Operazioni critiche → Policy statica (ownership check)
    [HttpPut("{id}")]
    [Authorize(Policy = "CanModifyBoard")]
    public async Task<IActionResult> Update(string id, BoardDto dto)
    {
        // Solo creatore o collaboratori arrivano qui
        // Policy verifica ownership tramite handler custom
    }

    [HttpDelete("{id}")]
    [Authorize(Policy = "CanModifyBoard")]
    public async Task<IActionResult> Delete(string id)
    {
        // Stesso check di ownership
    }

    // Mix: permesso base + ownership
    [HttpPost("{id}/collaborators")]
    [RequirePermission("write:board")] // Claim base
    [Authorize(Policy = "CanModifyBoard")] // + Ownership
    public async Task<IActionResult> AddCollaborator(string id, string userId)
    {
        // Entrambe le policy devono passare (AND logico)
    }
}
```

**Vantaggi di questo approccio ibrido:**
- **Scalabilità**: aggiungi 50 endpoint CRUD senza toccare Program.cs
- **Flessibilità**: logica custom dove serve (ownership, limiti, audit)
- **Manutenibilità**: permessi base cambiano dal sistema di identity, ownership resta in codice

---

## Esempio Alternativo: Solo Policy Dinamiche

**Scenario**: Microservizio CRUD puro senza ownership (es. servizio di configurazione).

## Esempio Alternativo: Solo Policy Dinamiche

**Scenario**: Microservizio CRUD puro senza ownership (es. servizio di configurazione).

**1. Program.cs**
```csharp
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();
// Nessuna policy statica necessaria
```

**2. Controller (ConfigurationController.cs)**
```csharp
[ApiController]
[Route("api/config")]
public class ConfigurationController : ControllerBase
{
    [HttpGet]
    [RequirePermission("read:config")]
    public IActionResult GetAll() { }

    [HttpPost]
    [RequirePermission("write:config")]
    public IActionResult Create(ConfigDto dto) { }

    [HttpPut("{id}")]
    [RequirePermission("write:config")]
    public IActionResult Update(string id, ConfigDto dto) { }

    [HttpDelete("{id}")]
    [RequirePermission("delete:config")]
    public IActionResult Delete(string id) { }
}
```

**Vantaggio**: Zero file extra (nessun Requirement, nessun Handler), solo attributi.

---

## Esempio Alternativo: Solo Policy Statiche (Legacy)

**Scenario**: Sistema legacy con 5 ruoli fissi e logica complessa.

**1. Program.cs**
```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CanModifyDeal", policy =>
        policy.Requirements.Add(new DealOwnershipRequirement()));
    
    options.AddPolicy("CanApproveDeal", policy =>
    {
        policy.RequireRole("Trader");
        policy.RequireClaim("seniority", "Senior", "Lead");
        policy.Requirements.Add(new DealAmountLimitRequirement(1_000_000));
    });
});

builder.Services.AddScoped<IAuthorizationHandler, DealOwnershipHandler>();
builder.Services.AddScoped<IAuthorizationHandler, DealAmountLimitHandler>();
```

**2. Requirements/DealOwnershipRequirement.cs**
```csharp
namespace YourApp.Authorization.Requirements;

/// <summary>
/// Verifica che l'utente sia il creatore del deal o un admin.
/// </summary>
public class DealOwnershipRequirement : IAuthorizationRequirement { }
```

**3. Handlers/DealOwnershipHandler.cs**
```csharp
namespace YourApp.Authorization.Handlers;

public class DealOwnershipHandler : AuthorizationHandler<DealOwnershipRequirement>
{
    private readonly IDealRepository _repo;

    public DealOwnershipHandler(IDealRepository repo) => _repo = repo;

    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        DealOwnershipRequirement requirement)
    {
        var userId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null) return;

        // Estrai dealId dalla route
        if (context.Resource is not HttpContext httpContext) return;
        var dealId = httpContext.GetRouteValue("id")?.ToString();
        if (dealId == null) return;

        var deal = await _repo.GetByIdAsync(dealId);
        if (deal == null) return;

        // Logica: proprietario o admin
        if (deal.CreatedBy == userId || context.User.IsInRole("Admin"))
            context.Succeed(requirement);
    }
}
```

**4. Controllers/DealsController.cs**
```csharp
[ApiController]
[Route("api/deals")]
public class DealsController : ControllerBase
{
    [HttpPut("{id}")]
    [Authorize(Policy = "CanModifyDeal")]
    public async Task<IActionResult> Update(string id, DealDto dto)
    {
        // Policy garantisce che solo owner/admin arrivano qui
        // ...
    }

    [HttpPost("{id}/approve")]
    [Authorize(Policy = "CanApproveDeal")]
    public async Task<IActionResult> Approve(string id)
    {
        // Trader senior/lead con limit check
        // ...
    }
}
```

---

## Tabella Comparativa: Quale Approccio Usare?

| Criterio | Policy Dinamiche (Provider) | Policy Statiche (Requirement) | Mix |
|----------|----------------------------|-------------------------------|-----|
| **Numero policy** | 10+ identiche | 3-5 diverse | Entrambi |
| **Complessità logica** | Solo claim/ruolo | Business logic (DB, API) | Semplice + Complessa |
| **File da creare** | 2 (Provider + Attribute) | 3 per policy (Policy + Req + Handler) | 2 + 3N |
| **Scalabilità** | ⭐⭐⭐⭐⭐ Infinite policy | ⭐⭐⭐ Buona | ⭐⭐⭐⭐⭐ |
| **Testabilità** | ⭐⭐⭐⭐ Integration test | ⭐⭐⭐⭐⭐ Unit + Integration | ⭐⭐⭐⭐⭐ |
| **Quando usare** | CRUD, microservizi, OAuth | Ownership, limiti, audit | Applicazioni enterprise |
| **Esempio** | Servizio configurazione | Sistema banking legacy | Board collaborativi |

**Regola pratica:**
- **Inizi con <5 endpoint?** → Policy Statiche (evita over-engineering)
- **Prevedi 20+ endpoint simili?** → Policy Dinamiche (evita duplicazione)
- **Sistema enterprise con entrambi?** → Mix (best of both worlds)

---
```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CanModifyDeal", policy =>
        policy.Requirements.Add(new DealOwnershipRequirement()));
});

builder.Services.AddScoped<IAuthorizationHandler, DealOwnershipHandler>();
```

**2. Requirements/DealOwnershipRequirement.cs**
```csharp
namespace YourApp.Authorization.Requirements;

/// <summary>
/// Verifica che l'utente sia il creatore del deal o un admin.
/// </summary>
public class DealOwnershipRequirement : IAuthorizationRequirement { }
```

**3. Handlers/DealOwnershipHandler.cs**
```csharp
namespace YourApp.Authorization.Handlers;

public class DealOwnershipHandler : AuthorizationHandler<DealOwnershipRequirement>
{
    private readonly IDealRepository _repo;

    public DealOwnershipHandler(IDealRepository repo) => _repo = repo;

    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        DealOwnershipRequirement requirement)
    {
        var userId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null) return;

        // Estrai dealId dalla route
        if (context.Resource is not HttpContext httpContext) return;
        var dealId = httpContext.GetRouteValue("id")?.ToString();
        if (dealId == null) return;

        var deal = await _repo.GetByIdAsync(dealId);
        if (deal == null) return;

        // Logica: proprietario o admin
        if (deal.CreatedBy == userId || context.User.IsInRole("Admin"))
            context.Succeed(requirement);
    }
}
```

**4. Controllers/DealsController.cs**
```csharp
[ApiController]
[Route("api/deals")]
public class DealsController : ControllerBase
{
    [HttpPut("{id}")]
    [Authorize(Policy = "CanModifyDeal")]
    public async Task<IActionResult> Update(string id, DealDto dto)
    {
        // Policy garantisce che solo owner/admin arrivano qui
        // ...
    }
}
```

---

## Struttura File Consigliata

### Approccio Mix (Consigliato per Enterprise)

```
YourApp/
├── Authorization/
│   ├── PermissionPolicyProvider.cs        # Policy dinamiche
│   ├── RequirePermissionAttribute.cs      # Attributo custom
│   ├── Requirements/
│   │   ├── BoardOwnershipRequirement.cs   # Policy statiche
│   │   ├── DealAmountLimitRequirement.cs
│   │   └── MinimumTenureRequirement.cs
│   └── Handlers/
│       ├── BoardOwnershipHandler.cs
│       ├── DealAmountLimitHandler.cs
│       └── MinimumTenureHandler.cs
├── Controllers/
│   ├── BoardsController.cs                # Mix: [RequirePermission] + [Authorize(Policy)]
│   └── DealsController.cs
└── Program.cs                              # Provider + Policy statiche
```

### Solo Policy Dinamiche (Microservizi CRUD)

```
YourApp/
├── Authorization/
│   ├── PermissionPolicyProvider.cs
│   └── RequirePermissionAttribute.cs
├── Controllers/
│   └── ConfigurationController.cs         # Solo [RequirePermission]
└── Program.cs                              # Solo Provider
```

### Solo Policy Statiche (Legacy o <5 Policy)

```
YourApp/
├── Authorization/
│   ├── Requirements/
│   │   └── DealOwnershipRequirement.cs
│   └── Handlers/
│       └── DealOwnershipHandler.cs
├── Controllers/
│   └── DealsController.cs                 # Solo [Authorize(Policy)]
└── Program.cs                              # Solo AddAuthorization()
```

---

## Quick Reference

### Ciclo di Vita Valutazione Policy

1. Controller riceve request con `[Authorize(Policy = "X")]`
2. Framework recupera policy "X" dalla configurazione
3. Per ogni requirement nella policy:
   - Trova handler registrati per quel requirement type
   - Esegue `HandleRequirementAsync()` su ogni handler
4. Se almeno un handler chiama `context.Succeed()` per OGNI requirement → autorizzato
5. Se almeno un handler chiama `context.Fail()` → negato (shortcut)
6. Se nessun handler succede → negato per default

### Metodi Chiave AuthorizationHandlerContext

| Metodo | Effetto | Quando Usare |
|--------|---------|--------------|
| `context.Succeed(requirement)` | Marca requirement come soddisfatto | Condizione positiva verificata |
| `context.Fail()` | Blocca immediatamente autorizzazione | Violazione critica (es. ban utente) |
| `return` (nessuna call) | Handler neutro, lascia decidere altri | Condizione non applicabile |

### Scope DI Consigliati

| Servizio | Scope | Motivazione |
|----------|-------|-------------|
| `IAuthorizationHandler` | **Scoped** | Accesso a DB/HttpContext per request |
| Repository iniettati | Scoped | Consistenza transazionale |
| `ILogger` | Singleton | Servizio stateless |

---

**Fine documento. Usa questo come reference per ogni implementazione di policy in .NET.**
