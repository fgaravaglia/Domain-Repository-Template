# Writing Standards — cosa distingue una spec buona da una mediocre

## User Stories

**Formula:** `As a [attore specifico], I want to [azione], so that [beneficio]`

Regole:

- L'attore non è mai genericamente "user" se il requirements.md distingue ruoli (es. "admin",
  "guest", "buyer", "seller", "team owner"). Usa il ruolo giusto.
- Il beneficio non può essere una ripetizione dell'azione. `"I want to reset my password, so
  that I can reset my password"` è uno scarto, non un beneficio.
- Beneficio debole vs forte:
  - ❌ "so that it works better" (non verificabile, non specifico)
  - ✅ "so that I don't lose access to my account if I forget my credentials"
- 2-4 story per feature: se ne servono di più, la feature è probabilmente due feature.

## Acceptance Criteria (BDD)

**Formula:** `Given [contesto], when [azione], then [risultato]`

Regole:

- **Given** deve essere uno stato verificabile, non un'intenzione. ❌ "Given the user wants to
  log in" → ✅ "Given a registered user with valid credentials on the login page".
- **When** è una singola azione osservabile, non un flusso multi-step. Se servono più step,
  spezza in più criteri.
- **Then** deve essere osservabile dall'esterno (cosa vede/riceve l'utente o il sistema a
  valle), non uno stato interno non verificabile. ❌ "then the system processes it correctly"
  → ✅ "then the user sees a confirmation message and receives a confirmation email within 1
  minute".
- Scrivi sempre almeno un acceptance criteria per il **happy path** e almeno uno per il
  **primo fallimento più probabile** (dato invalido, permesso mancante, risorsa non trovata).
- Evita assoluti non verificabili tipo "always", "correctly", "properly" senza specificare
  cosa significano in pratica.

## Edge Cases — checklist per tipologia

Non tutte si applicano sempre: usa quella pertinente al tipo di feature, poi aggiungi quelle
specifiche al dominio.

**Form / Input utente**

- Campo obbligatorio mancante
- Formato invalido (email, numero, data)
- Input al limite (0 caratteri, lunghezza massima, valore negativo dove non ha senso)
- Doppio submit / submit concorrente
- Caratteri speciali / injection-like input (livello requisito: "il sistema valida e rifiuta",
  non come lo fa tecnicamente)

**Autenticazione / Autorizzazione**

- Credenziali errate ripetute (lockout?)
- Sessione scaduta a metà azione
- Utente senza permesso che tenta l'azione
- Account disattivato/sospeso che tenta login

**Pagamenti / Transazioni**

- Pagamento rifiutato dal provider
- Timeout durante la transazione (stato incerto)
- Importo zero o negativo
- Doppio addebito su retry

**Notifiche / Comunicazioni**

- Destinatario con canale non disponibile (email invalida, push disabilitata)
- Invio fallito → retry o segnalazione?
- Notifiche duplicate per lo stesso evento

**Ricerca / Filtri**

- Nessun risultato trovato
- Query vuota
- Troppi risultati (paginazione, limite)

**Upload file**

- File troppo grande
- Formato non supportato
- Upload interrotto a metà

**Stati / Workflow**

- Transizione di stato non valida (es. annullare un ordine già spedito)
- Azione concorrente sullo stesso oggetto da due attori
- Stato "orfano" se un passaggio precedente fallisce

## Domain Model — livello di dettaglio corretto

- Attributi a livello di **dominio**, non di database: "email (univoca, obbligatoria)" non
  "email VARCHAR(255) UNIQUE NOT NULL".
- Includi attributi impliciti ma necessari al comportamento descritto nelle user story (se una
  story dice "so that I can track my order status", l'entità Order ha bisogno di un attributo
  status anche se il requirements.md non lo nomina esplicitamente — ma poi va segnalato se è
  un'assunzione forte).
- Non disegnare relazioni o chiavi esterne: qui è puro modello concettuale, l'architettura
  arriva dopo e in un'altra conversazione.
