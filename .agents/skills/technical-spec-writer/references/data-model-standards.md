# Data Model Standards

Differenza col Domain Model funzionale: lì gli attributi sono concettuali ("email, univoca").
Qui devono essere implementabili: qualcuno potrebbe generare uno schema da questo documento
senza doverti richiedere altro.

## Regole

- **Tipo concreto per ogni campo**: string/int/decimal/boolean/datetime/enum/uuid — non lasciare
  tipi generici tipo "dato" o "info".
- **Nullabilità esplicita**: ogni campo dichiara se può essere nullo o no. Non è un dettaglio,
  è la fonte più comune di bug in produzione.
- **Vincoli di unicità e integrità**: quali campi sono univoci, quali sono chiavi esterne verso
  quali entità, quali hanno un valore di default.
- **Indici a livello logico**: se un campo verrà quasi certamente interrogato spesso (es. userId
  su una tabella di eventi), segnalalo come candidato indice — non serve il DDL, basta la nota.
- **Enum esplicitati**: se un campo è "status" o simile, elenca i valori possibili e le
  transizioni valide (spesso derivano dagli Stati/Workflow della spec funzionale).
- **Non inventare campi non richiesti dalla spec funzionale a monte**: se serve un campo che la
  spec non menziona per supportare un requisito tecnico (es. `version` per optimistic locking),
  aggiungilo ma segnalalo esplicitamente come aggiunta tecnica, non come requisito di business.

## Esempio

```markdown
| Entity | Field | Type | Constraints | Notes |
|--------|-------|------|-------------|-------|
| User | id | uuid | PK | |
| User | email | string | unique, not null | indicizzato per lookup login |
| User | status | enum(active, suspended, deleted) | not null, default: active | transizioni: active→suspended→active, active→deleted (non reversibile) |
| Order | id | uuid | PK | |
| Order | userId | uuid | FK → User.id, not null | indicizzato — query frequenti per utente |
| Order | totalAmount | decimal(10,2) | not null, >= 0 | |
```

## Cosa NON fare

- ❌ Scegliere il tipo di database (Postgres vs Mongo) qui dentro — quella è una decisione che,
  se non già presa dal progetto, va segnalata come ⚠️ Richiede ADR nella sezione Technical
  Decisions, non decisa implicitamente scegliendo una sintassi SQL-like.
- ❌ Scrivere DDL reale (`CREATE TABLE...`) — livello logico, non fisico.
