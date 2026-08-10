# METODOLOGIA DI STIMA: FIBONACCI STORY POINTS

Tecnica di stima alternativa/complementare alla matrice Valore vs Sforzo
(`kb_prioritization_matrix.md`). Le due non sono ridondanti: **Value/Effort decide COSA fare
prima** (prioritizzazione), **Story Points stimano QUANTO costa** una story già decisa
(capacity planning, sprint sizing). Usa Fibonacci quando l'utente chiede esplicitamente stime
in punti, sprint planning, o quando sta scomponendo un'Epica in un batch di story da pianificare
insieme.

## 1. LA SCALA

**1, 2, 3, 5, 8, 13** (Fibonacci). Non usare numeri fuori scala (no 4, 6, 7, 10...): la
non-linearità è voluta, forza a distinguere "un po' più grande" da "molto più grande" invece di
inseguire falsa precisione.

## 2. I TRE ASSI DI STIMA

Ogni punteggio nasce dalla combinazione di:

- **Complessità**: quante parti mobili, quanta logica condizionale, quante integrazioni.
- **Sforzo**: tempo di sviluppo puro, incluso testing.
- **Rischio**: incertezza tecnica, dipendenze esterne non controllate, novità tecnologica per il
  team.

Una story piccola ma rischiosa (es. prima integrazione con un provider mai usato prima) può
valere più di una story grande ma familiare. Non stimare solo sulla lunghezza percepita del
lavoro.

## 3. RIFERIMENTO RAPIDO

| Punti | Significato tipico | Esempio |
| ------- | -------------------- | --------- |
| 1 | Banale, nessuna ambiguità, nessun rischio | Cambiare un testo statico, un colore |
| 2 | Piccola, un solo componente coinvolto | Aggiungere un campo a un form esistente |
| 3 | Media, più componenti ma pattern noto | Nuovo endpoint CRUD con validazione |
| 5 | Sostanziosa, logica non banale o più integrazioni | Flusso di reset password completo |
| 8 | Grande, rischio o complessità significativi | Integrazione pagamento con nuovo provider |
| 13 | Epica travestita da story | Qualunque cosa richieda più sprint |

## 4. REGOLA DI SPLIT — 8 E 13 SONO UN CAMPANELLO D'ALLARME

Ogni story stimata **8 o 13** va segnalata come **"Candidate for Splitting"**, non stimata e
basta. Una story così grande nasconde quasi sempre più valori indipendenti fusi insieme.

**Come dividerla** (in ordine di preferenza, coerente col Vertical Slicing —
vedi `kb_user_story_guide.md`):

1. **Per variante di workflow**: happy path come story 1, ogni ramo alternativo/eccezione come
   story separata (es. "checkout con carta" vs "checkout con paypal").
2. **Per regola di business**: se la story applica più regole indipendenti, ognuna può essere
   una story a sé che aggiunge valore incrementale.
3. **Per tipo di operazione**: create/read/update/delete raramente devono essere nella stessa
   story se non servono tutte insieme al rilascio del valore.
4. **Per segmento utente**: stessa funzionalità ma per persona diversa (es. "vista admin" vs
   "vista utente standard") se i due possono essere rilasciati separatamente.

Evita di dividere per **layer tecnico** (frontend/backend/DB) — quello è lo split che il
Vertical Slicing vieta esplicitamente, perché nessuno dei due pezzi da solo porta valore
all'utente finale.

## 5. RATIONALE DI STIMA — COSA SCRIVERE

Ogni stima va giustificata in 1-2 frasi che citano esplicitamente quale dei tre assi (Complessità
/ Sforzo / Rischio) pesa di più. Una stima senza rationale è un numero a caso: non basta scrivere
"5 punti", va scritto "5 punti — complessità media per la logica di validazione multi-step, rischio
basso perché pattern già usato altrove nel progetto".
