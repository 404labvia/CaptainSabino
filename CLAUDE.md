# CaptainSabino

App iOS per la gestione delle spese di bordo, creata esclusivamente per il Capitano Sabino.

## Panoramica

CaptainSabino è un'applicazione SwiftUI con SwiftData per tracciare le spese dello yacht. Include scansione scontrini con OCR (Claude Vision API), generazione report PDF e gestione categorie spese.

## Stack Tecnologico

- **Framework**: SwiftUI + SwiftData
- **Target**: iPhone only, iOS 17.6+
- **OCR**: Claude Vision API (Anthropic)
- **Persistenza**: SwiftData (modelli locali)
- **PDF**: UIGraphicsPDFRenderer con grafici a torta

## Struttura Progetto

```
CaptainSabino/
├── Models/
│   ├── Expense.swift        # Modello spesa principale
│   ├── Category.swift       # Categorie spese (predefinite + custom)
│   ├── YachtSettings.swift  # Impostazioni yacht e API key
│   ├── LearnedKeyword.swift # Keywords apprese per OCR
│   └── Reminder.swift       # Promemoria (non attivo in UI)
├── Views/
│   ├── ContentView.swift    # Tab bar principale
│   ├── DashboardView.swift  # Dashboard con grafici
│   ├── ExpenseListView.swift # Lista spese
│   ├── AddExpenseView.swift  # Aggiunta spesa (design moderno)
│   ├── EditExpenseView.swift # Modifica spesa
│   ├── ReportListView.swift  # Lista report PDF salvati
│   ├── SettingsView.swift    # Impostazioni
│   ├── OnboardingView.swift  # Setup iniziale
│   └── CameraReceiptView.swift # Scansione scontrini
├── Services/
│   ├── ReceiptOCRService.swift # OCR con Claude Vision
│   ├── PDFService.swift        # Generazione PDF report
│   ├── NotificationService.swift # Notifiche locali
│   └── EmailService.swift      # Invio email
└── CaptainSabinoApp.swift      # Entry point
```

## Convenzioni Codice

### Struttura File Swift
```swift
// MARK: - Properties
// MARK: - Body
// MARK: - Computed Properties
// MARK: - View Components
// MARK: - Methods
// MARK: - Preview
```

### Lingua
- **Commenti**: Italiano
- **Nomi variabili/funzioni**: Inglese (convenzione Swift)
- **UI Text**: Inglese

### Pattern SwiftUI
- Usare `@Query` per fetch SwiftData
- Usare `@State` per stato locale view
- Usare `@Environment(\.modelContext)` per persistenza
- Preferire computed properties per logica derivata

## Funzionalità Principali

### OCR Scontrini
- Usa Claude Vision API per estrarre: importo, data, categoria, merchant
- Supporta formati data europei (DD/MM/YYYY) e americani (MM/DD/YYYY)
- Sistema di learned keywords per migliorare riconoscimento categoria

### Report PDF
- Salvati in `Documents/Reports/`
- Includono grafico a torta per categorie
- Funzioni: View (QuickLook), Share, Regenerate, Delete

### Navigazione
- Tab 0: Dashboard (grafici mensili)
- Tab 1: Expenses (lista spese)
- Tab 2: Placeholder (bottone + centrale)
- Tab 3: Reports (lista PDF)
- Tab 4: Settings

## Sicurezza

- **Claude API Key**: Salvata in YachtSettings, MAI esporre in log o codice
- Non committare file con credenziali

## Design UI

- Stile moderno con cards e ombre
- Colori: Blu per azioni primarie, Verde per Report
- Corner radius: 12-15pt per cards
- Usare `Color(.secondarySystemBackground)` per sfondi cards

## Comandi Utili

```bash
# Build
xcodebuild -scheme CaptainSabino -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean
xcodebuild clean -scheme CaptainSabino
```

## Note Sviluppo

- I report generati da Dashboard/Expenses/Reports usano lo stesso `GenerateReportSheet`
- `ToastView` per feedback utente su azioni completate
- QuickLook per visualizzazione PDF nativi iOS
