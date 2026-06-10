import SwiftUI

struct RootView: View {
  @EnvironmentObject private var store: StudyStore
  @EnvironmentObject private var notificationManager: NotificationManager

  var body: some View {
    TabView {
      ImportView()
        .tabItem {
          Label("Import", systemImage: "square.and.arrow.down")
        }

      UnitsView()
        .tabItem {
          Label("Units", systemImage: "rectangle.stack")
        }

      ReviewView()
        .tabItem {
          Label("Review", systemImage: "rectangle.on.rectangle.angled")
        }
        .badge(store.dueCount)

      ReminderView()
        .tabItem {
          Label("Reminders", systemImage: "bell")
        }
    }
    .tint(AppTheme.teal)
    .task {
      await Task.yield()
      store.prepareInitialDataIfNeeded()
      notificationManager.prepareIfNeeded()
    }
  }
}
