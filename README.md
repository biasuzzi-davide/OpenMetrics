# OpenMetrics

OpenMetrics e una piccola app macOS da menu bar per tenere sotto controllo metriche di sistema e utilizzo AI.

## Funzionalita

- Barra menu configurabile con CPU, RAM, disco, batteria, rete, Claude e Codex.
- Pannello SwiftUI con tab Panoramica, Dettagli, AI e Impostazioni.
- Metriche sistema: CPU, load average, core attivi, RAM, cache, memoria wired/compressa, swap, disco, batteria, rete, uptime, stato termico, temperature componenti, host e versione macOS.
- Lettura traffico rete in ingresso/uscita, interfaccia attiva e indirizzo IP.
- Lettura batteria con percentuale, stato di carica e tempo stimato residuo.
- Tab AI con usage Claude e Codex, piano rilevato, limiti sessione/settimanali, reset, crediti e stato credenziali.
- Modalita AI configurabile tra percentuale usata o residua, con reset relativo o assoluto.
- Aggiornamento manuale e intervallo automatico configurabile a 1, 2, 5 o 10 secondi.
- Avvio automatico al login.
- Nessuna dipendenza esterna: usa SwiftUI, IOKit, Security e API native macOS.

## Credenziali AI

OpenMetrics usa le sessioni locali gia presenti:

- Claude: Keychain di Claude Code oppure `~/.claude/.credentials.json` (`CLAUDE_CONFIG_DIR` supportato).
- Codex: `CODEX_HOME/auth.json`, `~/.config/codex/auth.json`, `~/.codex/auth.json` oppure Keychain.

Se le credenziali non sono disponibili, il tab AI mostra lo stato `login`.

## Struttura progetto

```text
Sources/OpenMetrics/App/       App SwiftUI e store
Sources/OpenMetrics/Models/    Snapshot dati
Sources/OpenMetrics/Services/  Lettura metriche native macOS
Sources/OpenMetrics/Support/   Formatter e chiavi impostazioni
Sources/OpenMetrics/Views/     UI menu bar, tab e componenti
Tests/OpenMetricsTests/        Test formatter e mapping AI
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
