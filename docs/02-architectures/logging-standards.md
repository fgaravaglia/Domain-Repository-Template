# Logging & Traceability in .NET — Onion Architecture
## Guidelines & Best Practices

---

## 1. Principio fondamentale: il Correlation ID

Il Correlation ID è il filo che tiene insieme un'intera richiesta attraverso tutti i layer. Ogni altra decisione sul logging dipende da questa struttura.

### Perché è critico in Onion Architecture

In un'architettura a layer (Core → Application → Infrastructure → Presentation), una singola richiesta attraversa almeno 4-6 layer prima di tornare al client. Senza un identificatore condiviso, il debugging diventa archaeologia.

```
Request in → [Controller] → [UseCase] → [DomainService] → [Repository] → DB
                  |               |              |                |
                  v               v              v                v
              correlationId    correlationId  correlationId   correlationId
              (generato)       (propagato)    (propagato)     (propagato)
```

### Generazione e propagazione

```csharp
// --- Infrastructure Layer ---
// Middleware: primo punto di ingresso, genera il correlationId
// PERCHÉ: solo qui abbiamo accesso alla richiesta HTTP inbound e al response outbound

public class CorrelationIdMiddleware
{
    private const string CorrelationIdHeader = "X-Correlation-Id";
    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Accetta un correlationId esterno (eseguito per chiamate inter-servizio)
        // altrimenti ne genera uno nuovo
        var correlationId = context.Request.Headers.TryGetValue(
            CorrelationIdHeader, out var existing)
            ? existing.ToString()
            : Guid.NewGuid().ToString();

        // Inietta nel contesto di logging per tutta la durata della richiesta
        using (LogContext.PushProperties(new { CorrelationId = correlationId }))
        {
            // Propaga anche nel response, utile per il client downstream
            context.Response.OnStarted(() =>
            {
                context.Response.Headers[CorrelationIdHeader] = correlationId;
                return Task.CompletedTask;
            });

            await _next(context);
        }
    }
}
```

```csharp
// --- Program.cs ---
// Ordine CRITICO: CorrelationId middleware deve essere il primo nella pipeline
// PERCHÉ: se passa dopo altri middleware (es. exception handler), quei log
// non avranno mai il correlationId

app.UseMiddleware<CorrelationIdMiddleware>();
app.UseMiddleware<GlobalExceptionHandler>();  // dopo
```

---

## 2. Il modello del dominio come centro di gravità

### Struttura del contesto di logging

Il logging non è un cross-cutting concern da gestire solo all'infrastruttura. Il dominio *produce eventi significativi* che devono essere catturati. Il pattern giusto è quello di separare il *cosa loggare* dal *come loggare*.

```
┌──────────────────────────────────────────────┐
│  Core Layer (Domain)                         │
│  → Definisce COSA è rilevante loggare        │
│  → Domain Events, nessuna dipendenza a log   │
├──────────────────────────────────────────────┤
│  Application Layer                           │
│  → Orchestra, decide QUANDO loggare          │
│  → UseCase/Handler: log di entrata/uscita    │
├──────────────────────────────────────────────┤
│  Infrastructure Layer                        │
│  → Implementa COME loggare                   │
│  → Sinks, formatter, middleware              │
├──────────────────────────────────────────────┤
│  Presentation Layer                          │
│  → Log minimo (solo correlationId generation)│
└──────────────────────────────────────────────┘
```

### Core Layer — Domain Events (nessun logger iniettato)

```csharp
// --- Core Layer ---
// Il dominio non sa niente di logging. Emette eventi.
// PERCHÉ: mantenere il Core puro garantisce testabilità
// e rispetta il principio di inversione delle dipendenze

public class OrderPlaced : IDomainEvent
{
    public Guid OrderId { get; }
    public decimal TotalAmount { get; }
    public DateTimeOffset OccurredOn { get; }

    public OrderPlaced(Guid orderId, decimal totalAmount)
    {
        OrderId = orderId;
        TotalAmount = totalAmount;
        OccurredOn = DateTimeOffset.UtcNow;
    }
}

public class Order
{
    private readonly List<IDomainEvent> _events = new();

    public void Place(decimal amount)
    {
        // Validazione dominio...
        _events.Add(new OrderPlaced(Id, amount));
    }

    // Espone gli eventi per la raccolta esterna
    public IReadOnlyCollection<IDomainEvent> GetEvents() => _events;
}
```

### Application Layer — UseCase con logging strutturato

```csharp
// --- Application Layer ---
// PERCHÉ: il UseCase è il punto orchestrale. Qui sappiamo
// sia il contesto business che la sequenza delle operazioni.
// È il posto naturale per loggare entrata, uscita, e anomalie.

public class PlaceOrderHandler : IRequestHandler<PlaceOrderCommand, OrderResult>
{
    private readonly IOrderRepository _repository;
    private readonly ILogger<PlaceOrderHandler> _logger;

    public PlaceOrderHandler(IOrderRepository repository, ILogger<PlaceOrderHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<OrderResult> Handle(PlaceOrderCommand command, CancellationToken ct)
    {
        // Log di entrata con dati strutturati
        // PERCHÉ: structured logging permette di filtrare/aggregare
        // nei sistemi di monitoring (Datadog, Grafana) senza parsare stringhe
        _logger.LogInformation(
            "PlaceOrder started for Customer {CustomerId} with {ItemCount} items",
            command.CustomerId,
            command.Items.Count);

        var order = new Order(command.CustomerId);
        order.Place(command.Items);

        await _repository.SaveAsync(order, ct);

        // Log degli eventi di dominio generati
        // PERCHÉ: questo è il ponte tra il dominio (puro) e il logging (infra)
        foreach (var domainEvent in order.GetEvents())
        {
            _logger.LogInformation(
                "DomainEvent {EventType} raised for Order {OrderId}",
                domainEvent.GetType().Name,
                order.Id);
        }

        _logger.LogInformation(
            "PlaceOrder completed. OrderId: {OrderId}, Total: {Total}",
            order.Id,
            order.TotalAmount);

        return OrderResult.Success(order.Id);
    }
}
```

---

## 3. Logging strutturato — Regole del gioco

### Livelli: cosa loggare dove

| Livello | Quando usarlo | Esempio |
|---|---|---|
| **Trace** | Solo durante sviluppo locale, mai in prod | Valori intermedi in un algoritmo |
| **Debug** | Flussi dettagliati, utili solo per troubleshooting | Parametri della query prima dell'esecuzione |
| **Information** | Eventi business significativi | Ordine creato, utente autenticato |
| **Warning** | Situazioni anomale ma non fatali | Retry su chiamata esterna, dato mancante con fallback |
| **Error** | Fallimento operativo recuperabile | Eccezione nella chiamata a servizio esterno |
| **Critical** | Fallimento del sistema, non recuperabile | Database irraggiungibile, OOM |

### Anti-pattern da evitare

```csharp
// ❌ WRONG — logging con string interpolation
// PERCHÉ: perde la struttura. Non puoi filtrare per OrderId nei log aggregati
_logger.LogInformation($"Order {order.Id} placed for {amount}");

// ✅ CORRECT — structured logging con placeholder
_logger.LogInformation("Order {OrderId} placed for {Amount}", order.Id, amount);
```

```csharp
// ❌ WRONG — loggare eccezioni come stringa
_logger.LogError("Errore: " + ex.Message);

// ✅ CORRECT — passa l'eccezione come parametro dedicato
// PERCHÉ: i log aggregator catturano lo stack trace strutturato
_logger.LogError(ex, "Failed to save Order {OrderId}", order.Id);
```

```csharp
// ❌ WRONG — loggare oggetti interi (PII risk + payload massiccio)
_logger.LogInformation("User data: {@User}", user);

// ✅ CORRECT — projetta solo i campi rilevanti
_logger.LogInformation("User logged in. UserId: {UserId}, Role: {Role}", user.Id, user.Role);
```

---

## 4. Infrastructure Layer — Configurazione e Sink

```csharp
// --- Infrastructure Layer ---
// PERCHÉ: la configurazione del logging è una responsabilità di infrastruttura.
// Il Core e l'Application non devono sapere se loghiamo su file, Seq, o Datadog.

public static class LoggingExtensions
{
    public static IHostBuilder ConfigureLogging(this IHostBuilder hostBuilder)
    {
        return hostBuilder.UseSerilog((context, services, configuration)
        {
            configuration
                .MinimumLevel.Information()
                .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
                .Enrich.FromLogContext()  // Cattura il CorrelationId iniettato dal middleware
                .Enrich.WithEnvironment()
                .Enrich.WithProcessId()
                .WriteTo.Console(formatTemplate:
                    "[{Timestamp:HH:mm:ss} {Level:u3}] [{CorrelationId}] {Message:lj}{NewLine}{Exception}")
                .WriteTo.Seq(context.Configuration["Logging:Seq:Url"]!);
        });
    }
}
```

---

## 5. Propagazione tra servizi (distributed tracing)

Quando il sistema non è monolitico, il correlationId deve viaggiare oltre il boundary del servizio.

```csharp
// --- Infrastructure Layer ---
// HttpClient handler che propaga il CorrelationId nelle chiamate outbound
// PERCHÉ: se il Servizio A chiama il Servizio B, entrambi devono condividere
// lo stesso correlationId per permettere il tracing end-to-end

public class CorrelationIdDelegatingHandler : DelegatingHandler
{
    private const string CorrelationIdHeader = "X-Correlation-Id";

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        // Recupera il correlationId dal contesto di logging corrente
        var correlationId = LogContext.EnrichWithOutgoingCorrelationId(request, CorrelationIdHeader);

        _logger.LogDebug(
            "Outbound call to {Uri} with CorrelationId {CorrelationId}",
            request.RequestUri,
            correlationId);

        return await base.SendAsync(request, ct);
    }
}

// Registrazione nel DI
services.AddTransient<CorrelationIdDelegatingHandler>();
services.AddHttpClient<IExternalServiceClient, ExternalServiceClient>()
    .AddTransientHttpRequestHandler<CorrelationIdDelegatingHandler>();
```

---

## 6. Global Exception Handler — Ultimo baluardo

```csharp
// --- Infrastructure Layer ---
// PERCHÉ: cattura tutto ciò che non è stato gestito nei layer superiori.
// A questo punto il correlationId è già nel contesto (middleware eseguito prima).

public class GlobalExceptionHandler : IMiddleware
{
    private readonly ILogger<GlobalExceptionHandler> _logger;

    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            // Il CorrelationId è già nel LogContext grazie al middleware
            _logger.LogCritical(ex,
                "Unhandled exception. StatusCode will be 500. Path: {Path}",
                context.Request.Path);

            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            await context.Response.WriteAsJsonAsync(new
            {
                Error = "Internal Server Error",
                // Restituisci il correlationId al client per il suo troubleshooting
                CorrelationId = context.Response.Headers["X-Correlation-Id"]
            });
        }
    }
}
```

---

## 7. Checklist operativa

Prima di fare il deploy di un nuovo feature o servizio, verifica:

- [ ] Il correlationId viene generato nel middleware e propagato nel LogContext
- [ ] Tutte le chiamate outbound (HttpClient) propagano l'header `X-Correlation-Id`
- [ ] I Domain Events vengono loggati nel layer Application, non nel Core
- [ ] Nessun log usa string interpolation — tutto strutturato con placeholder
- [ ] Le eccezioni vengono passate come parametro, non come stringa
- [ ] I livelli di logging sono appropriati per ambiente (Trace/Debug disabilitati in prod)
- [ ] Il response HTTP include sempre il correlationId per il client
- [ ] Il GlobalExceptionHandler è registrato *dopo* il CorrelationId middleware

---

## 8. Scenario ipotetico: come traccio un bug in produzione

Un cliente segnala un errore al checkout. Il flow di investigazione diventa:

1. Il client riceve nel response l'header `X-Correlation-Id: abc-123-def`
2. Cerco `abc-123-def` nel sistema di log aggregato (Seq, Datadog, ecc.)
3. Vedo l'intera catena: middleware → controller → useCase → repository → chiamata esterna
4. Identifico dove il flusso si è interrotto in meno di 30 secondi

Senza correlationId, lo stesso scenario richiede correlazioni manuali tra timestamp, IP e guess. Non è investigazione, è fortuna.

---

*Versione: 1.0 | Stack: .NET 8, Serilog, Onion Architecture*