import SwiftUI
import SwiftData

@main
struct CaptainSabinoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Expense.self,
            Category.self,
            Reminder.self,
            YachtSettings.self
        ])
    }
}
