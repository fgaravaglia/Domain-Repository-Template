# Functional Spec — Template di output

Usa esattamente questa struttura per `functional-spec.md`. Sostituisci tutto ciò che è tra `[...]`.

```markdown
# [App Name] — Functional Specification

## Summary
[3-line synthesis of the product: cosa fa, per chi, valore principale]

## Domain Model

| Entity | Key Attributes |
|--------|----------------|
| [Entity1] | [attr1, attr2, attr3...] |
| [Entity2] | [attr1, attr2, attr3...] |

## Features

### Feature 1: [Name]

**Description:**
[Cosa fa la feature dal punto di vista dell'utente — mai "come" è implementata]

**Sub-requirements:**
1. [requisito atomico e verificabile]
2. [requisito atomico e verificabile]
3. ...

**User Stories:**
- As a [tipo di utente specifico, non "user"], I want to [azione concreta], so that [beneficio reale]
- As a [...], I want to [...], so that [...]

**Acceptance Criteria:**
- Given [contesto/stato iniziale], when [azione], then [risultato osservabile]
- Given [...], when [...], then [...]

**Edge Cases:**
- [scenario di fallimento o input anomalo] → [comportamento atteso]
- [scenario di fallimento o input anomalo] → [comportamento atteso]

### Feature 2: [Name]
[ripeti la stessa struttura]

## Open Questions
- ⚠️ [ambiguità o assunzione fatta, con la domanda esplicita da porre allo stakeholder]
- ⚠️ [...]
```

## Note di compilazione

- **Non omettere mai nessuna sezione**, anche se minima: se una feature davvero non ha edge
  case ovvi, scrivi comunque almeno "nessun edge case rilevante oltre alla validazione
  standard input" — non lasciare la sezione vuota senza commento, sembra un errore.
- **Domain Model va compilato per intero**, anche per app molto semplici (minimo 2-3 entità).
- **L'ordine delle Feature segue l'ordine del requirements.md** originale, salvo che l'utente
  chieda esplicitamente di riordinare per priorità.
- Se il requirements.md include già un Domain Model o entità esplicite, non riscriverle da
  zero: arricchiscile con gli attributi che emergono dalle user story che stai scrivendo.
