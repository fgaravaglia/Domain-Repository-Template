# Best Practices per REST API (Technology Agnostic)

this document explain the best practices and design standards for REST API, whatever the tecnology stack is.

## 1. Architettura e Organizzazione

**Separazione delle responsabilità**

Struttura il codice in layer distinti:

- **Dominio**: logica business, regole, entità
- **Applicazione**: orchestrazione, casi d'uso
- **Interfaccia**: endpoint HTTP, serializzazione
- **Infrastruttura**: database, servizi esterni

**Esempio pratico**: Se costruisci un e-commerce, `Product`, `Order` stanno nel dominio. La logica "crea ordine e invia email" sta nell'applicazione. Gli endpoint REST nell'interfaccia.

## 2. Design degli Endpoint

**Usa sostantivi, non verbi**

- ✅ `GET /products`
- ✅ `POST /orders`
- ❌ `GET /getProducts`
- ❌ `POST /createOrder`

**Nomi plurali per collezioni**

```
/customers          # collezione
/customers/123      # risorsa singola
/customers/123/orders  # sotto-risorsa
```

**Gerarchia massima 2-3 livelli**

- ✅ `/customers/123/orders`
- ❌ `/customers/123/orders/456/items/789/details`

**Usa query params per filtri e opzioni**

```
GET /products?category=electronics&price_max=1000&sort=price_desc
GET /orders?status=pending&created_after=2024-01-01
```

## 3. Metodi HTTP

**Usali secondo il loro significato**

| Metodo | Scopo | Idempotente | Safe |
|--------|-------|-------------|------|
| GET | Leggi risorsa | Sì | Sì |
| POST | Crea risorsa | No | No |
| PUT | Sostituisci completamente | Sì | No |
| PATCH | Modifica parziale | No* | No |
| DELETE | Elimina risorsa | Sì | No |

**Idempotente = stessa richiesta N volte = stesso risultato*

**Esempi**

```
GET    /products          → lista prodotti
GET    /products/123      → dettaglio prodotto 123
POST   /products          → crea nuovo prodotto
PUT    /products/123      → sostituisci prodotto 123
PATCH  /products/123      → aggiorna solo alcuni campi
DELETE /products/123      → elimina prodotto 123
```

## 4. Status Code HTTP

**Usa quelli corretti**

**2xx - Successo**

- `200 OK`: operazione riuscita (GET, PUT, PATCH)
- `201 Created`: risorsa creata (POST) - aggiungi header `Location: /products/123`
- `204 No Content`: successo senza body (DELETE, PUT)

**4xx - Errore client**

- `400 Bad Request`: dati non validi
- `401 Unauthorized`: non autenticato (manca token)
- `403 Forbidden`: autenticato ma senza permessi
- `404 Not Found`: risorsa non esiste
- `409 Conflict`: conflitto (es. email già usata)
- `422 Unprocessable Entity`: validazione semantica fallita
- `429 Too Many Requests`: rate limit superato

**5xx - Errore server**

- `500 Internal Server Error`: errore generico
- `503 Service Unavailable`: servizio temporaneamente offline

## 5. Formato delle Risposte

**JSON come standard**

**Struttura consistente per successo**

```json
{
  "id": "123",
  "name": "Product Name",
  "price": 29.99,
  "created_at": "2024-01-25T10:30:00Z"
}
```

**Struttura consistente per errori**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "I dati forniti non sono validi",
    "details": [
      {
        "field": "email",
        "message": "Email non valida"
      }
    ]
  }
}
```

**Liste con metadati**

```json
{
  "data": [...],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 156,
    "total_pages": 8
  }
}
```

## 6. Versionamento

**Scegli una strategia e mantienila**

**Opzione 1: URL (più comune)**

```
/api/v1/products
/api/v2/products
```

**Opzione 2: Header**

```
GET /api/products
Accept: application/vnd.myapi.v1+json
```

**Opzione 3: Query param (sconsigliato)**

```
/api/products?version=1
```

**Quando versioni**: breaking changes (cambi campi, rimuovi endpoint, cambi comportamento).

## 7. Paginazione

**Sempre obbligatoria per liste**

**Offset-based (semplice)**

```
GET /products?page=2&per_page=20
```

**Cursor-based (per dataset grandi)**

```
GET /products?cursor=eyJpZCI6MTIzfQ&limit=20
```

**Rispondi con metadati**

```json
{
  "data": [...],
  "pagination": {
    "page": 2,
    "per_page": 20,
    "total": 156,
    "has_next": true,
    "next_cursor": "eyJpZCI6MTQzfQ"
  }
}
```

**Limita il per_page massimo (es. 100)**

## 8. Filtri e Ricerca

**Query parameters chiari**

```
GET /products?category=electronics
GET /products?min_price=10&max_price=100
GET /products?search=laptop
GET /products?sort=price_desc
GET /products?fields=id,name,price  # selezione campi
```

**Operatori espliciti**

```
GET /orders?created_at[gte]=2024-01-01&created_at[lte]=2024-12-31
GET /products?tags[in]=electronics,gadgets
```

## 9. Sicurezza

**Autenticazione**

- Token-based (JWT, OAuth2)
- API Keys per machine-to-machine
- Mai credenziali in URL

**Autorizzazione**

- Role-based (RBAC)
- Permission-based
- Resource-level checks

**Pratiche essenziali**

- HTTPS obbligatorio
- CORS configurato correttamente
- Rate limiting (es. 100 req/min)
- Input validation e sanitization
- Non esporre stack trace in produzione
- Usa OWASP API Security Top 10

```
# Headers sicurezza
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000
```

## 10. Performance

**Cache HTTP**

```
# Response headers
Cache-Control: public, max-age=3600
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"

# Request condizionale
If-None-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"
→ 304 Not Modified (se non cambiato)
```

**Compression**

- Abilita gzip/brotli
- Solo per risposte > 1KB

**Operazioni asincrone**

```
POST /exports
→ 202 Accepted
{
  "job_id": "abc123",
  "status_url": "/exports/abc123/status"
}

GET /exports/abc123/status
→ 200 OK
{
  "status": "processing",
  "progress": 45
}
```

**Field selection**

```
GET /users/123?fields=id,name,email  # solo campi richiesti
```

## 11. HATEOAS (Hypermedia)

**Links per navigazione (opzionale ma utile)**

```json
{
  "id": "123",
  "name": "Order #123",
  "status": "pending",
  "links": {
    "self": "/orders/123",
    "cancel": "/orders/123/cancel",
    "customer": "/customers/456"
  }
}
```

## 12. Gestione Errori

**Consistenza sempre**

```json
{
  "error": {
    "code": "PRODUCT_NOT_FOUND",
    "message": "Il prodotto richiesto non esiste",
    "request_id": "req-abc123",
    "timestamp": "2024-01-25T10:30:00Z"
  }
}
```

**Validazione dettagliata**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validazione fallita",
    "details": [
      {
        "field": "email",
        "code": "INVALID_FORMAT",
        "message": "Email non valida"
      },
      {
        "field": "age",
        "code": "OUT_OF_RANGE",
        "message": "L'età deve essere tra 18 e 120"
      }
    ]
  }
}
```

## 13. Documentazione

**OpenAPI/Swagger**

- Genera da codice o scrivi manualmente
- Include esempi per ogni endpoint
- Documenta tutti i parametri
- Specifica autenticazione richiesta

**Esempio di documentazione minima**

```yaml
/products:
  get:
    summary: Lista prodotti
    parameters:
      - name: category
        in: query
        schema:
          type: string
    responses:
      200:
        description: Lista prodotti
        content:
          application/json:
            example:
              data: [...]
```

## 14. Rate Limiting

**Comunica i limiti**

```
# Response headers
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1706181000

# Quando superato
429 Too Many Requests
Retry-After: 60
```

## 15. Monitoring e Logging

**Logga sempre**

- Request ID unico per tracciare
- Timestamp
- Endpoint chiamato
- Status code
- Tempo di risposta
- User ID (se autenticato)
- IP address

**Non loggare**

- Password
- Token
- Dati sensibili (carte di credito, etc.)

**Metriche da monitorare**

- Latenza (p50, p95, p99)
- Error rate
- Throughput
- Disponibilità

## 16. Testing

**Test a 3 livelli**

**Unit**: logica business isolata

**Integration**: endpoint completi

```
POST /orders
→ verifica 201
→ verifica Location header
→ verifica struttura response
→ verifica ordine salvato in DB
```

**End-to-end**: scenari utente completi

```
1. POST /auth/login → ottieni token
2. GET /products → lista prodotti
3. POST /cart/items → aggiungi al carrello
4. POST /orders → crea ordine
5. GET /orders/123 → verifica ordine
```

## 17. Idempotenza

**Usa chiavi di idempotenza per POST**

```
POST /payments
Idempotency-Key: unique-key-123
```

Se ripeti la stessa richiesta con stessa chiave → stessa risposta, nessuna azione duplicata.

## 18. Naming Conventions

**Usa convenzioni chiare e consistenti**

**Campi JSON**: snake_case o camelCase (scegli uno)

```json
// snake_case (più comune in API)
{
  "created_at": "2024-01-25",
  "user_name": "john"
}

// camelCase
{
  "createdAt": "2024-01-25",
  "userName": "john"
}
```

**Date e timestamp**: ISO 8601

```
2024-01-25T10:30:00Z
2024-01-25T10:30:00+01:00
```

**Booleani**: is_, has_, can_

```json
{
  "is_active": true,
  "has_permission": false,
  "can_edit": true
}
```

## 19. Soft Delete

**Considera soft delete per risorse importanti**

```
DELETE /products/123
→ 204 No Content

# Internamente: deleted_at = now(), non rimuovi fisicamente

# Per hard delete
DELETE /products/123?permanent=true
```

## 20. Bulk Operations

**Supporta operazioni batch quando serve**

```
POST /products/bulk
{
  "items": [
    { "name": "Product 1", "price": 10 },
    { "name": "Product 2", "price": 20 }
  ]
}

→ 207 Multi-Status
{
  "results": [
    { "status": 201, "id": "123" },
    { "status": 400, "error": "Invalid price" }
  ]
}
```

## Checklist Finale

**Design**

- [ ] Nomi endpoint chiari e consistenti
- [ ] Metodi HTTP corretti
- [ ] Status code appropriati
- [ ] Versionamento implementato

**Dati**

- [ ] JSON come formato standard
- [ ] Struttura errori consistente
- [ ] Paginazione obbligatoria
- [ ] Validazione robusta

**Sicurezza**

- [ ] HTTPS only
- [ ] Autenticazione implementata
- [ ] CORS configurato
- [ ] Rate limiting attivo
- [ ] Input sanitization

**Performance**

- [ ] Caching HTTP
- [ ] Compression abilitata
- [ ] Indici database ottimizzati
- [ ] Query N+1 risolte

**Qualità**

- [ ] Documentazione OpenAPI
- [ ] Test integration
- [ ] Logging strutturato
- [ ] Monitoring metriche

---

## Principi Guida

1. **Consistenza**: mantieni lo stesso stile in tutta l'API
2. **Semplicità**: preferisci soluzioni semplici a quelle complesse
3. **Documentazione**: se non è documentato, non esiste
4. **Retrocompatibilità**: non rompere i client esistenti
5. **Security by default**: sicurezza non è opzionale
6. **Performance matters**: ogni millisecondo conta
7. **Fail fast**: valida presto, fallisci subito
8. **Be predictable**: comportamento prevedibile > cleverness

**Inizia semplice, aggiungi complessità solo quando necessario. Una API ben progettata è facile da usare, prevedibile e mantiene le promesse.**
