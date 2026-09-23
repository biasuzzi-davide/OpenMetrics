# OpenMetrics

OpenMetrics e una piccola app macOS da menu bar per tenere sotto controllo metriche di sistema e utilizzo AI.

## Funzionalita

- Barra menu configurabile con CPU, RAM, disco, batteria, rete, Claude e Codex: ogni voce e un glifo con il valore, a larghezza fissa.
- Pannello traslucido stile Centro di Controllo con tab Panoramica, AI e Dettagli; Liquid Glass su macOS 26, materiale classico prima.
- Panoramica a moduli: anelli e numeri grandi per CPU, RAM, disco e batteria, sparkline degli ultimi 60 campioni per CPU, RAM e rete.
- Tab AI con un anello per ogni quota (sessione, settimanale, modelli) e barre per crediti e spesa extra.
- Finestra Impostazioni nativa (⌘,) con schede Generale, Barra menu e AI.
- Finestra "Utilizzo AI" con lo storico di token e costi nel tempo, filtrabile per periodo, provider, modello e progetto.
- Metriche sistema: CPU, load average, core attivi, RAM, cache, memoria wired/compressa, swap, disco, batteria, rete, uptime, stato termico, temperature componenti, host e versione macOS.
- Lettura traffico rete in ingresso/uscita, interfaccia attiva e indirizzo IP.
- Lettura batteria con percentuale, stato di carica e tempo stimato residuo.
- Tab AI con usage Claude e Codex, piano rilevato, limiti sessione/settimanali, reset, crediti e stato credenziali.
- Modalita AI configurabile tra percentuale usata o residua, con reset relativo o assoluto.
- Grafico a barre impilate per tipo di token, modello, progetto o provider, con granularita giorno, settimana o mese.
- Tabelle ordinabili per modello e per progetto, esportazione CSV dei periodi visualizzati.
- Icona nel Dock opzionale: l'app resta nella barra menu e diventa una finestra quando serve.
- Tinte semantiche per metrica (CPU, RAM, disco, batteria, provider AI) che passano ad arancio e rosso sopra soglia.
- Aggiornamento manuale e intervallo automatico configurabile a 1, 2, 5 o 10 secondi.
- Avvio automatico al login.
- Nessuna dipendenza esterna: usa SwiftUI, IOKit, Security e API native macOS.

## Storico utilizzo

La finestra "Utilizzo AI" si apre dal pulsante grafico nel pannello, dall'icona nel Dock o
rilanciando l'app dal Finder. Ricostruisce lo storico leggendo i log JSONL che i due client
scrivono gia in locale, senza chiamate di rete:

- Claude Code: `~/.claude/projects/**/*.jsonl` (`CLAUDE_CONFIG_DIR` supportato, anche con piu percorsi separati da virgola).
- Codex: `~/.codex/sessions/**/*.jsonl` (`CODEX_HOME` supportato).

La prima scansione indicizza tutto lo storico; dopo vengono lette soltanto le righe nuove di
ogni file. L'indice sta in `~/Library/Application Support/OpenMetrics/usage-index.bin`.

### Costi

Il costo mostrato e una **stima a tariffe API**, calcolata dai token per modello. Con un
abbonamento Claude o ChatGPT quei token non si pagano a consumo: serve a confrontare il peso
dei periodi, non a leggere la spesa reale. La spesa effettiva compare solo nel tab AI, dove
`Extra` riporta i crediti Claude fuori abbonamento.

Le tariffe Claude sono integrate. Per i modelli senza listino, fra cui quelli Codex, i token
sono contati ma esclusi dal costo e la finestra lo segnala. Il pulsante "Configura prezzi"
crea `~/Library/Application Support/OpenMetrics/pricing.json` con i modelli mancanti: finche
i valori restano a zero il modello continua a essere trattato come senza tariffa.

## Credenziali AI

OpenMetrics usa le sessioni locali gia presenti:

- Claude: Keychain di Claude Code oppure `~/.claude/.credentials.json` (`CLAUDE_CONFIG_DIR` supportato).
- Codex: `CODEX_HOME/auth.json`, `~/.config/codex/auth.json`, `~/.codex/auth.json` oppure Keychain.

Se le credenziali non sono disponibili, il tab AI mostra lo stato `login`.

## Struttura progetto

```text
Sources/OpenMetrics/App/         App SwiftUI, store e finestra storico
Sources/OpenMetrics/Models/      Snapshot dati, record e aggregazioni di utilizzo
Sources/OpenMetrics/Services/    Lettura metriche native macOS, log AI e listino prezzi
Sources/OpenMetrics/Support/     Formatter, cache binaria, policy Dock, chiavi impostazioni
Sources/OpenMetrics/Views/       UI menu bar, tab e componenti
Sources/OpenMetrics/Views/Theme/ Tinte, card, badge e sfondo vetro del pannello
Sources/OpenMetrics/Views/Settings/ Finestra Impostazioni
Sources/OpenMetrics/Views/Usage/ Finestra utilizzo: filtri, grafici e tabelle
Resources/                       Icona dell'app (AppIcon.icns)
scripts/                         Generatore dell'icona
Tests/OpenMetricsTests/          Test formatter, mapping AI, aggregazioni e cache
```

## Requisiti

- macOS 13 o superiore.
- Swift 6 toolchain.

## Build

```sh
make app
```

L'app viene creata in:

```text
dist/OpenMetrics.app
```

Per avviarla:

```sh
make run
```

L'icona in `Resources/AppIcon.icns` e generata da `scripts/make-icon.swift`; per rigenerarla dopo
una modifica al disegno:

```sh
make icon
```

## Distribuzione macOS

Senza Apple Developer Program puoi creare un DMG installabile con drag in Applications:

```sh
make dmg
```

Il file viene creato in:

```text
dist/OpenMetrics-macOS.dmg
```

Al primo avvio macOS mostrera comunque l'avviso Gatekeeper: apri con click destro, `Open`, poi conferma.

Per creare lo ZIP firmato e notarizzato serve:

- account Apple Developer attivo;
- certificato `Developer ID Application` installato nel Keychain;
- profilo notarile salvato in `notarytool`.

Configura il profilo notarile una volta sola:

```sh
xcrun notarytool store-credentials openmetrics-notary \
  --apple-id "apple-id@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Poi crea lo ZIP distribuibile:

```sh
make notarize DISTRIBUTION_CODESIGN_ID="Developer ID Application: Nome Cognome (TEAMID)"
```

L'asset pronto per GitHub Release viene creato in:

```text
dist/OpenMetrics-macOS.zip
```

La workflow `.github/workflows/release.yml` pubblica lo stesso ZIP quando viene pushato un tag `v*`. Richiede questi secrets GitHub:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Secrets opzionali:

- `MACOS_CODESIGN_IDENTITY`
- `MACOS_KEYCHAIN_PASSWORD`

## Test

```sh
make test
```

## GitHub Pages

La pagina statica del progetto e in `docs/index.html`.

Per pubblicarla su GitHub Pages: repository Settings, Pages, Deploy from a branch, branch `main`, cartella `/docs`.

URL atteso:

```text
https://biasuzzi-davide.github.io/OpenMetrics/
```
