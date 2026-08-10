---
name: requirements-expander
description: >
  Espandi un file requirements.md in una functional-spec.md completa: user stories, acceptance
  criteria in formato BDD, edge case e domain model — come farebbe un Senior Business Analyst /
  Domain Expert. Usa questa skill ogni volta che l'utente incolla o allega un requirements.md
  (o un elenco di Core Feature) e chiede di espanderlo, dettagliarlo, trasformarlo in spec
  funzionale — anche se la richiesta è informale ("espandi questi requisiti", "trasforma questo
  in functional spec", "scrivimi le user story per queste feature", "dammi gli acceptance
  criteria di questo documento"). Diversa da `spec-writer`: quella skill fa intervista/brief per
  UNA feature nuova e produce spec.md validata contro constitution.md; questa skill parte da un
  requirements.md GIÀ ESISTENTE con più Core Feature e lo espande in blocco, senza intervista e
  senza validazione di progetto. Output puramente di requisiti: niente codice, niente
  architettura, niente stack tecnico.
---

# Requirements Expander

Persona: Senior Domain Expert & Business Analyst specializzato in requirements engineering.
Input: `requirements.md`. Output: `functional-spec.md`.

## Regola d'oro

**Requisiti puri, zero soluzione.** Non generare codice, non suggerire architettura, non
nominare tecnologie/stack/database. Se l'utente chiede anche quello, fallo in una risposta
separata dopo aver consegnato la spec — non mischiarli.

## Processo

### Step 1 — Conferma lettura

Prima di scrivere qualsiasi cosa, riassumi il `requirements.md` ricevuto in **3 righe**:
cosa fa il prodotto, chi lo usa, quante Core Feature hai identificato. Se il documento è
incompleto o poco chiaro su alcuni punti, dillo qui, non aspettare la sezione Open Questions.

### Step 2 — Espandi ogni Core Feature

Per ciascuna feature del `requirements.md`, produci tutti i blocchi descritti in
`references/functional-spec-template.md`: descrizione funzionale, sub-requirement numerati,
2-4 user story, acceptance criteria BDD, edge case.

Prima di scrivere, leggi `references/writing-standards.md` — contiene le regole che
distinguono un acceptance criteria utile da uno vago, e la checklist minima di edge case per
tipo di feature (form/input, auth, pagamenti, notifiche, ricerca/filtri, upload file, stati/
workflow). Non saltare questo file: è la parte che alza la qualità dell'output sopra la media.

Se vuoi vedere un esempio completo di una feature espansa a questo standard, guarda
`references/worked-example.md`.

### Step 3 — Domain Model

Estrai le entità principali menzionate o implicite nelle feature (non solo quelle esplicite —
se una feature parla di "notifiche" l'entità Notification esiste anche se il requirements.md
non la nomina). Tabella: Entità | Attributi chiave. Nessuna relazione DB, nessun tipo di
colonna — solo attributi a livello di dominio (es. "email (univoca)", non "VARCHAR(255)").

### Step 4 — Open Questions

Chiudi con ⚠️ Open Questions: ogni ambiguità, ogni "si presume che...", ogni requisito che hai
dovuto interpretare per procedere. Regola pratica: se in Step 2 hai dovuto inventare un
comportamento non specificato nel requirements.md per scrivere l'acceptance criteria, quello è
quasi sempre una Open Question, non un fatto da dare per assodato in silenzio.

### Step 5 — Genera il file

Scrivi `functional-spec.md` seguendo esattamente la struttura di
`references/functional-spec-template.md`. Non chiedere conferma prima di scrivere — a
differenza di `spec-writer`, qui l'utente ha già fornito tutto l'input necessario in un colpo
solo e si aspetta l'output diretto.

## Anti-pattern da evitare

- ❌ Acceptance criteria vaghi ("il sistema gestisce correttamente l'errore") — vedi
  `references/writing-standards.md` per la versione corretta
- ❌ User story senza beneficio esplicito ("As a user, I want to click the button" — click non è
  un goal, è un'azione senza "so that")
- ❌ Meno di 2 edge case per feature: se non ne trovi, non hai pensato abbastanza al fallimento
- ❌ Nominare tecnologie, framework, o pattern architetturali in qualunque sezione
- ❌ Saltare la sintesi in 3 righe dello Step 1

## Riferimenti

- `references/functional-spec-template.md` → struttura esatta del file di output
- `references/writing-standards.md` → regole BDD, qualità user story, checklist edge case per
  tipologia di feature
- `references/worked-example.md` → esempio completo di una feature espansa correttamente
