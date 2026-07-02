# OpenMetrics

OpenMetrics e una piccola app macOS da menu bar per vedere CPU, RAM, disco, batteria, rete, uptime e dettagli di sistema.

## Struttura

```text
Sources/OpenMetrics/App/       App SwiftUI e store
Sources/OpenMetrics/Models/    Snapshot dati
Sources/OpenMetrics/Services/  Lettura metriche native macOS
Sources/OpenMetrics/Support/   Formatter e chiavi impostazioni
Sources/OpenMetrics/Views/     UI menu bar, tab e componenti
```

## Funzioni

- Valori selezionabili direttamente nella barra menu.
- Tab Panoramica, Dettagli e Impostazioni.
- Intervallo di aggiornamento configurabile.
- Nessuna dipendenza esterna.

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

## Test

```sh
make test
```
