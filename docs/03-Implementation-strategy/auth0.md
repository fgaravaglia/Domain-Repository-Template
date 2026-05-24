# Guida Integrazione Auth0: React + .NET + Postman
Questa guida descrive la configurazione dell'ecosistema Auth0 per gestire l'autenticazione tra un frontend React e un backend .NET, inclusendo il setup per i test locali e la validazione lato server.

## 1. Configurazione API (Backend .NET)
L'entità "API" su Auth0 serve a definire la risorsa protetta e i permessi (scope) che il backend accetterà.Passaggi in Auth0 Dashboard:

- Vai su Applications > APIs e clicca su Create API
- In Settings, attiva:
  - Enable RBAC: ON
  - Add Permissions in the Access Token: ON
- In Permissions, definisci gli scope richiesti:
  - `read:boards`: Accesso in lettura ai dati delle board (partite, team, risultati).
  - `write:boards`: Aggiornamento dei risultati di una partita.
  - `read:forecast`: Visualizzazione dei forecast degli utenti.
  - `write:forecast`: Aggiornamento forecast.
  - `read:admin`: Accesso alle pagine amministrative.
  - `write:admin`: Aggiornamento configurazione e accesso in scrittura admin.

## 2. Creazione Web Application (Frontend React)
Gestisce il login degli utenti tramite browser.Passaggi in Auth0 Dashboard:
- Vai su Applications > Applications > Create Application; Type: Single Page Web Application.
- In Settings, configura:
  - Allowed Callback URLs
  - Allowed Logout URLs
  - Allowed Web Origins
  - Integrazione React:JavaScript

```xml 
// Configurazione Auth0Provider
<Auth0Provider
  domain="TUO_DOMINIO.auth0.com"
  clientId="TUO_CLIENT_ID"
  authorizationParams={{
    redirect_uri: window.location.origin,
    audience: "https://api.sales-solutions.it",
    scope: "openid profile email read:reports"
  }}
>
  <App />
</Auth0Provider>
```

## 3. Configurazione Backend .NET (Middleware & RBAC)
Il backend deve validare il JWT e verificare i permessi contenuti nel claim permissions.Installazione Pacchetti:

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

Implementazione in Program.cs:

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

// 1. Configurazione Autenticazione
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://TUO_DOMINIO.auth0.com/";
        options.Audience = "https://api.sales-solutions.it";
    });

// 2. Configurazione Autorizzazione (RBAC)
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("NormalUser", policy => 
        policy.RequireClaim("permissions", "read:boards", "read:forecast", "write:forecast"));
    
    options.AddPolicy("Administrator", policy => 
        policy.RequireClaim("permissions", "write:boards", "read:admin", "write:admin"));
});

var app = builder.Build();

app.UseAuthentication(); // Deve venire prima di UseAuthorization
app.UseAuthorization();

app.MapControllers();
app.Run();
```

Protezione Controller:

```csharp
[Authorize("ReadReports")]
[HttpGet("reports")]
public IActionResult GetReports() => Ok(new { message = "Dati protetti caricati" });
```

## 4. Test con Postman (Machine-to-Machine)
Per testare le API localmente senza browser.Passaggi in Auth0:
- Crea App Machine to Machine.In Authorize API, seleziona la tua API e spunta gli scope necessari.
- Configurazione Postman (Auth Tab):
  - Type: OAuth 2.0
  - Grant Type: Client Credentials
  - Access Token URL: https://TUO_DOMINIO.auth0.com/oauth/token
  - Client ID / Secret: Dalla App M2M
  - Audience: https://api.sales-solutions.it

Riepilogo Parametri:

| Parametro | Valore | Note |
|-----------|--------|------|
| Domain | xxx.auth0.com | Uguale per FE e BE |
| Audience | https://api.sales-solutions.it | Deve coincidere in Auth0, React, .NET e Postman |
| Claim | permissions | Dove Auth0 inserisce gli scope nel JWT |

**Actionable Advice:** Esegui il backend e usa Postman per generare un token. Se ricevi un 401 Unauthorized, incolla il token su jwt.io e verifica che l'attributo aud sia esattamente quello configurato e che l'attributo iss finisca con lo slash /. 
Se ricevi 403 Forbidden, controlla che il claim permissions contenga lo scope richiesto dalla Policy.