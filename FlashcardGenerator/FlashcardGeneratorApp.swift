import SwiftUI

@main
struct FlashcardGeneratorApp: App {
  @StateObject private var store = StudyStore()
  @StateObject private var notificationManager = NotificationManager()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(store)
        .environmentObject(notificationManager)
    }
  }
}
