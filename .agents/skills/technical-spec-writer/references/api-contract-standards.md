# API Contract Standards

## Per ogni endpoint/evento, documenta sempre

1. **Metodo e path** (o nome evento, se è un'architettura event-driven)
2. **Auth**: pubblico? richiede token? richiede ruolo specifico?
3. **Request shape**: campi, tipi, obbligatorietà — coerenti col Data Model
4. **Response shape (success)**: campi, tipi
5. **Errori**: ogni codice di errore plausibile con quando si verifica — minimo 400 (input
   invalido) e il caso di errore più probabile per quello specifico endpoint (404, 409, 401...)

## Esempio

```markdown
### POST /api/orders
 
- **Auth**: richiede utente autenticato (Bearer token)
- **Request**:
  ```json
  { "items": [{ "productId": "uuid", "quantity": "int > 0" }] }
  ```

- **Response 201**:

  ```json
  { "orderId": "uuid", "status": "pending", "totalAmount": "decimal" }
  ```

- **Errors**:
  - `400` — items vuoto o quantity <= 0
  - `404` — productId non esistente
  - `409` — prodotto non più disponibile (out of stock)
  - `401` — token mancante o scaduto

```
 
## Regole
 
- Coerenza obbligatoria col Data Model: se il contract restituisce un campo, quel campo deve
  esistere nell'entità corrispondente (o essere segnalato come derivato/calcolato).
- Non inventare uno stile (REST vs GraphQL vs eventi) se il progetto ne ha già uno definito —
  rispettalo. Se non è definito e la scelta non è ovvia, segnala ⚠️ Richiede ADR invece di
  sceglierne uno a caso.
- Gli errori non sono un afterthought: ogni edge case elencato nella spec funzionale a monte
  (`spec.md` / `functional-spec.md`) dovrebbe avere un corrispettivo qui se coinvolge una
  chiamata API — se manca, è un segnale che il contract è incompleto.
