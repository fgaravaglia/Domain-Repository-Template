# Technical Spec — Template di output

```markdown
# [Feature/Prodotto] — Technical Specification
 
## Summary
[2-3 righe: cosa costruiamo tecnicamente e su quale spec funzionale si basa — link/riferimento
al file spec.md o functional-spec.md di origine]
 
## Architecture Overview
[Componenti coinvolti e comunicazione tra loro, livello concettuale. Diagramma Mermaid se utile
(sequence o component diagram).]
 
## Data Model
 
| Entity | Field | Type | Constraints | Notes |
|--------|-------|------|-------------|-------|
| [Entity] | [field] | [tipo concreto] | [nullable/unique/FK...] | [...] |
 
## API Contract
 
### [METHOD] /path/endpoint
- **Auth**: [richiesta? quale livello?]
- **Request**: [shape/schema]
- **Response 200**: [shape/schema]
- **Errors**: [400/401/404/409/500 — quando e cosa restituiscono]
 
## Non-Functional Requirements
[Per categoria — performance, sicurezza, scalabilità, osservabilità. Vedi
references/nfr-checklist.md. Se un target non è stato fornito dall'utente, scrivilo come
⚠️ Open Question, non inventarlo.]
 
## Technical Decisions
 
| Decisione | Motivazione | Reversibile? |
|-----------|-------------|--------------|
| [...] | [...] | Sì/No — se No e non ovvia → ⚠️ Richiede ADR (vedi easp-architecture-decision) |
 
## Implementation Plan (high-level)
[Sequenza macro di lavoro con dipendenze. Se esiste backlog da product-manager, referenzia i
gruppi di story invece di duplicarli.]
 
## Open Questions
- ⚠️ [...]
```
