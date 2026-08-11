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

<<<<<<< HEAD
## 4. VERTICAL SLICING — IL PRINCIPIO DI SCOMPOSIZIONE

Quando un'Epica viene divisa in più User Story, ogni story DEVE rappresentare una **fetta
verticale di valore** — un incremento completo e rilasciabile che l'utente percepisce, non un
livello dello stack tecnico.

**Sbagliato (scomposizione orizzontale/per layer):**
- Story 1: "Creare l'API backend per il carrello"
- Story 2: "Costruire la UI del carrello"

Nessuna delle due, da sola, produce valore per l'utente finale. Non sono nemmeno testabili
end-to-end in isolamento.

**Corretto (scomposizione verticale/per valore):**
- Story 1: "Come utente, voglio aggiungere un singolo articolo al carrello, così da poter
  procedere all'acquisto" (tocca UI + logica + persistenza, ma in versione minima)
- Story 2: "Come utente, voglio modificare la quantità di un articolo nel carrello, così da
  correggere errori senza ripartire da zero"

Ogni story verticale è più stretta in ampiezza (fa meno cose) ma completa in profondità
(attraversa tutti i layer necessari a essere demo-abile e testabile da sola).

**Test rapido**: se una story non può essere mostrata funzionante a uno stakeholder non tecnico
a fine sprint, probabilmente non è una fetta verticale — è un task tecnico travestito da story.

## 5. ESEMPIO CONCRETO
=======
## 4. ESEMPIO CONCRETO
>>>>>>> 6d651aa388907907bf4cc54d524b8c0f5be87f5d

**Story**: COME utente abbonato, VOGLIO sbloccare l'area video subito dopo il pagamento, PERCHÉ voglio iniziare la mia formazione senza attese.
**AC**:

1. GIVEN utente non abbonato, WHEN visita l'area video, THEN vede il pulsante 'Abbonati'.
<<<<<<< HEAD
2. GIVEN transazione Stripe completata con successo, WHEN il webhook registra l'evento, THEN lo stato passa a 'Premium' e la pagina sblocca i video.
=======
2. GIVEN transazione Stripe completata con successo, WHEN il webhook registra l'evento, THEN lo stato passa a 'Premium' e la pagina sblocca i video.
>>>>>>> 6d651aa388907907bf4cc54d524b8c0f5be87f5d
