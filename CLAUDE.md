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
│   ├── Expense.swift        # Modello spesa + EntryType enum + formattedCurrency
│   ├── Category.swift       # Categorie spese (predefinite + custom)
│   ├── YachtSettings.swift  # Impostazioni yacht e API key
│   ├── LearnedKeyword.swift # Keywords apprese per OCR
│   └── Reminder.swift       # Promemoria (non attivo in UI)
├── Views/
│   ├── ContentView.swift    # Tab bar + menu 3 opzioni (Manual/Receipt/Invoice)
│   ├── DashboardView.swift  # Dashboard con grafici a torta
│   ├── ExpenseListView.swift # Lista spese + EntryTypeBadge (C/R/I)
│   ├── AddExpenseView.swift  # Aggiunta spesa (design moderno con ZStack)
│   ├── EditExpenseView.swift # Modifica spesa
│   ├── ReportListView.swift  # Lista report PDF salvati
│   ├── SettingsView.swift    # Impostazioni (solo yacht name e API key)
│   ├── OnboardingView.swift  # Setup iniziale (semplificato)
│   ├── CameraReceiptView.swift # Scansione scontrini
│   └── InvoicePDFPickerView.swift # Picker per upload fatture PDF
├── Services/
│   ├── ReceiptOCRService.swift # OCR scontrini + fatture (Claude Vision)
│   ├── PDFService.swift        # Report PDF con colonna Type
│   ├── NotificationService.swift # Notifiche locali
│   └── EmailService.swift      # Invio email
├── Theme/
│   └── AppColors.swift         # Palette colori premium nautici
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
- **Solo formato data europeo** (DD/MM/YYYY)
- Sistema di learned keywords per migliorare riconoscimento categoria
- **Flusso fotocamera continuo**: dopo salvataggio da scan, ritorna automaticamente alla fotocamera

### Upload Fatture (PDF)
- Supporta upload di file PDF tramite document picker
- `InvoicePDFPickerView` per selezione file
- Estrae immagini da tutte le pagine del PDF
- Prompt Claude ottimizzato per fatture italiane
- Riconosce: Totale Fattura, Data Emissione, Fornitore, Categoria

### Entry Type Tracking
Ogni spesa ha un tipo di inserimento:
- **C** (Cash/Manual) - Inserimento manuale, colore arancione
- **R** (Receipt) - Scansione scontrino, colore verde
- **I** (Invoice) - Upload fattura PDF, colore viola

Badge visibile nella lista spese e colonna Type nel report PDF.

### Categorie Spese
Categorie predefinite: Fuel, Food, Maintenance, Crew, Supplies, Transport, Mooring, Insurance, Communication, **Parking**, Other
- Rimossi: Welder, Water Test

### Formato Valuta
- **Formato italiano ovunque**: € 1.234,56 (punto migliaia, virgola decimali)
- Extension `Double.formattedCurrency` in Expense.swift
- Applicato in: Dashboard, Liste spese, Report PDF

### Report PDF
- Salvati in `Documents/Reports/`
- Includono grafico a torta per categorie
- **Colonna Type** nella tabella dettagli (mostra C/R/I)
- **Legenda header su due colonne**: Yacht/Captain (sinistra), Entry Types C/R/I (destra)
- **Auto-open con QuickLook** dopo generazione (senza toast)
- **Click su card apre PDF** (QuickLook)
- **Menu opzioni**: solo Delete
- Ordinati per data più recente

### Rilevamento Duplicati
- Controllo automatico: stesso importo + stessa data
- **Badge rosso** "Possible Duplicate" sopra il bottone Save
- Non bloccante: permette comunque il salvataggio
- Attivo sia per input manuale che OCR

### Navigazione
- Tab 0: Dashboard (grafici mensili)
- Tab 1: Expenses (lista spese)
- Tab 2: Placeholder (bottone + centrale)
- Tab 3: Reports (lista PDF)
- Tab 4: Settings

## Sicurezza

- **Claude API Key**: Salvata in YachtSettings, MAI esporre in log o codice
- Non committare file con credenziali
- Rimossi campi Owner Email e Captain Email

## Design UI

### Palette Colori Premium Nautici (AppColors.swift)
Colori ispirati all'icona app (timone oro su sfondo navy):

| Colore | Hex | Uso |
|--------|-----|-----|
| `navy` | #1C2541 | Pulsante +, Add Expense, Cancel buttons |
| `gold` | #C9A961 | Tab bar selezionata, icone Settings |
| `cream` | #F5F5DC | Testo su sfondi scuri |
| `forestGreen` | #2D6A4F | Pulsanti Report/Generate PDF |
| `premiumYellow` | #F4C430 | Pulsante Save Expense |
| `royalBlue` | #1E56A0 | Sezione Date (calendario, selezione) |

### Generale
- Stile moderno con cards e ombre
- Corner radius: 12-15pt per cards
- Usare `Color(.secondarySystemBackground)` per sfondi cards

### AddExpenseView (Layout ZStack)
```swift
ZStack {
    ScrollView { /* contenuto */ }
    VStack {
        Spacer()
        saveButtonSection  // Badge duplicato + bottone giallo
    }
}
```
- **Ordine sezioni**: Amount → Date → Category → Notes
- **Quick date buttons**: Calendario | 2gg fa | Ieri | Oggi (più recente a destra)
- **Save button giallo** fisso in basso con shadow
- **DatePicker** con bottoni OK/Cancel

### Dashboard
- Grafico a torta con font size 26 per totale centrale
- Lista categorie: colonna importi minWidth 100, percentuale minWidth 36

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
- ContentView gestisce `onSaveCompleted` callback per flusso fotocamera continuo
- PDFService usa `formatCurrency()` per formato italiano nei report
- **Reset badge notifica** all'apertura app (`UNUserNotificationCenter.current().setBadgeCount(0)`)
- **Tab bar oro**: configurata con `UITabBarAppearance` in `configureTabBarAppearance()`
