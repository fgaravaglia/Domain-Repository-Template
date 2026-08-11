# NFR Checklist

Categorie da controllare sempre. Non tutte si applicano a ogni feature — ma vanno almeno
considerate ed escluse esplicitamente se irrilevanti, non saltate in silenzio.

## Performance

- Tempo di risposta atteso (solo se fornito dall'utente o desumibile da SLA esistenti — altrimenti ⚠️ Open Question)
- Volume atteso (richieste/secondo, dimensione dataset)
- Comportamento sotto carico (degradazione graduale? rifiuto? coda?)

## Sicurezza

- Dati sensibili coinvolti (PII, dati finanziari, credenziali) → livello di protezione richiesto
- Superficie di attacco nuova introdotta (nuovo endpoint pubblico, nuovo upload, nuova integrazione esterna)
- Se il progetto è in ambito regolamentato (es. banking/DORA per il contesto UniCredit
  dell'utente), segnalalo esplicitamente come vincolo — non è opzionale

## Scalabilità

- La feature deve reggere crescita orizzontale? È previsto multi-tenancy?
- Ci sono colli di bottiglia noti nell'architettura esistente che questa feature aggrava?

## Osservabilità

- Cosa va loggato/monitorato per capire se la feature funziona in produzione?
- Metriche di business da tracciare (non solo tecniche) — spesso derivano direttamente dagli
  Acceptance Criteria della spec funzionale

## Compliance / Regolatorio (se applicabile)

- GDPR, data retention, audit trail — solo se il dominio lo richiede, non aggiungere per default

## Regola pratica sui target numerici

Un NFR senza numero verificabile non è un NFR, è un'intenzione. Ma **non inventare il numero**:
se l'utente non l'ha dato, scrivi la categoria come rilevante e marca il target mancante come
⚠️ Open Question con la domanda esplicita da fare (es. "⚠️ Qual è il volume di richieste
concorrenti atteso su questo endpoint? Necessario per dimensionare il rate limiting.").
