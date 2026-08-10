# GUIDA ALLA USER STORY PERFETTA

Una User Story descrive un valore dal punto di vista dell'utente.

## 1. IL FORMATO STANDARD

**COME** [Persona/Ruolo] **VOGLIO** [Azione/Funzionalità] **PERCHÉ** [Valore/Beneficio]

## 2. IL METODO I.N.V.E.S.T

- **I (Independent)**: Non deve dipendere da altre storie.
- **N (Negotiable)**: Lascia spazio alla discussione tecnica.
- **V (Valuable)**: Porta un beneficio chiaro all'utente o al business.
- **E (Estimable)**: È comprensibile quanto basta per stimarne lo sforzo.
- **S (Small)**: Completabile in 1-3 giorni di sviluppo.
- **T (Testable)**: Ha criteri di accettazione univoci.

## 3. CRITERI DI ACCETTAZIONE (Given-When-Then)

- **GIVEN**: Il contesto iniziale (es. "Dato che l'utente è autenticato").
- **WHEN**: L'azione compiuta (es. "Quando clicca su Paga Ora").
- **THEN**: Il risultato atteso (es. "Allora riceve l'accesso immediato").

## 4. ESEMPIO CONCRETO

**Story**: COME utente abbonato, VOGLIO sbloccare l'area video subito dopo il pagamento, PERCHÉ voglio iniziare la mia formazione senza attese.
**AC**:

1. GIVEN utente non abbonato, WHEN visita l'area video, THEN vede il pulsante 'Abbonati'.
2. GIVEN transazione Stripe completata con successo, WHEN il webhook registra l'evento, THEN lo stato passa a 'Premium' e la pagina sblocca i video.
