# Worked Example

Input `requirements.md` (estratto):

> Core Feature: Password Reset
> Gli utenti registrati devono poter recuperare l'accesso se dimenticano la password.

Output atteso per questa feature, allo standard richiesto:

```markdown
### Feature 3: Password Reset

**Description:**
Consente a un utente registrato che ha dimenticato la password di riottenere l'accesso al
proprio account tramite un link di reset inviato all'email associata.

**Sub-requirements:**
1. L'utente può richiedere un reset inserendo l'email associata al proprio account.
2. Il sistema invia un link di reset valido per un tempo limitato all'email fornita, se esiste
   un account associato.
3. Il sistema non rivela se l'email esiste o meno nel sistema (messaggio generico).
4. Il link scaduto o già utilizzato non può essere riutilizzato per impostare una nuova password.
5. Dopo il reset riuscito, tutte le sessioni attive dell'utente vengono invalidate.

**User Stories:**
- As a registered user who forgot my password, I want to request a password reset via email,
  so that I can regain access to my account without contacting support.
- As a registered user, I want the reset link to expire after a limited time, so that my
  account stays protected if someone else gains access to my inbox later.
- As a security-conscious user, I want all my other sessions to be logged out after a
  password reset, so that an attacker who had access to my old password loses access
  immediately.

**Acceptance Criteria:**
- Given a registered user on the "forgot password" page, when they submit their registered
  email, then they see a generic confirmation message ("if this email exists, you'll receive a
  link") regardless of whether the email exists.
- Given a valid, unexpired reset link, when the user submits a new valid password, then the
  password is updated and the user is redirected to the login page with a success message.
- Given a reset link older than the expiration window, when the user opens it, then they see
  an "expired link" message and an option to request a new one.
- Given a reset link that has already been used once, when the user opens it again, then the
  system rejects it as invalid.
- Given a successful password reset, when it completes, then all other active sessions for
  that user are invalidated immediately.

**Edge Cases:**
- Email inserita non corrisponde a nessun account → messaggio generico identico al caso
  esistente (no user enumeration)
- Utente richiede reset più volte in rapida successione → solo l'ultimo link generato è valido,
  o si applica un rate limit (⚠️ da chiarire con stakeholder, vedi Open Questions)
- Nuova password inserita non rispetta i requisiti minimi → errore inline, link non consumato
- Utente apre il link di reset ma nel frattempo l'account è stato disattivato → accesso negato
  con messaggio dedicato
```

Cosa rende questo esempio allo standard giusto:

- Le sub-requirement 3, 4, 5 non erano scritte esplicitamente nel requirements.md originale —
  sono standard di dominio impliciti in "password reset" che un BA esperto aggiunge, ma
  **andrebbero comunque verificate in Open Questions** se il requirements.md non le conferma.
- Gli acceptance criteria coprono happy path + 3 varianti di fallimento, tutti osservabili.
- Gli edge case includono un caso esplicitamente segnalato come ambiguo (rate limiting) invece
  di essere deciso in silenzio.
