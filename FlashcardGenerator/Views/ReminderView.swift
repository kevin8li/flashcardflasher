import SwiftUI
import UserNotifications

struct ReminderView: View {
  @EnvironmentObject private var store: StudyStore
  @EnvironmentObject private var notificationManager: NotificationManager

  @State private var statusMessage: String?

  private let weekdays: [(Int, String)] = [
    (2, "Mon"),
    (3, "Tue"),
    (4, "Wed"),
    (5, "Thu"),
    (6, "Fri"),
    (7, "Sat"),
    (1, "Sun")
  ]

  var body: some View {
    NavigationStack {
      AppScreen {
        ScrollView {
          VStack(spacing: 16) {
            AppHeader(
              section: "Reminders",
              detail: "Schedule review sessions",
              systemImage: "bell"
            )

            HStack(spacing: 12) {
              StatTile(
                title: "Due now",
                value: "\(store.dueCount)",
                systemImage: "bell.badge",
                color: AppTheme.coral
              )

              StatTile(
                title: "Terms",
                value: "\(store.terms.count)",
                systemImage: "character.book.closed",
                color: AppTheme.teal
              )
            }

            settingsPanel
          }
          .padding()
          .frame(maxWidth: .infinity)
        }
      }
      .navigationTitle("Reminders")
      .onAppear {
        notificationManager.refreshAuthorizationStatus()
      }
    }
  }

  private var settingsPanel: some View {
    VStack(alignment: .leading, spacing: 16) {
      Toggle("Review reminders", isOn: Binding(
        get: { notificationManager.settings.enabled },
        set: { enabled in
          notificationManager.updateSettings { $0.enabled = enabled }
          if enabled {
            schedule()
          } else {
            notificationManager.scheduleNotifications()
            statusMessage = "Reminders turned off."
          }
        }
      ))
      .tint(AppTheme.teal)

      DatePicker(
        "Reminder time",
        selection: Binding(
          get: { notificationManager.reminderDate },
          set: { notificationManager.setReminderDate($0) }
        ),
        displayedComponents: .hourAndMinute
      )
      .tint(AppTheme.teal)

      VStack(alignment: .leading, spacing: 10) {
        Text("Days")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AppTheme.ink)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
          ForEach(weekdays, id: \.0) { weekday, label in
            let selected = notificationManager.settings.weekdays.contains(weekday)

            Button {
              notificationManager.toggleWeekday(weekday)
            } label: {
              Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? .white : AppTheme.ink)
                .background(
                  selected ? AppTheme.teal : Color.white,
                  in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? AppTheme.teal : AppTheme.border)
                )
            }
            .buttonStyle(.plain)
          }
        }
      }

      HStack {
        Image(systemName: notificationManager.settings.enabled ? "bell.fill" : "bell.slash")
          .foregroundStyle(notificationManager.settings.enabled ? AppTheme.teal : AppTheme.muted)

        Text(notificationManager.authorizationText)
          .font(.subheadline)
          .foregroundStyle(AppTheme.muted)
      }

      PrimaryActionButton(
        title: "Save Reminder",
        systemImage: "checkmark",
        color: AppTheme.teal
      ) {
        schedule()
      }

      if let statusMessage {
        Text(statusMessage)
          .font(.subheadline)
          .foregroundStyle(AppTheme.muted)
      }
    }
    .padding(16)
    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
  }

  private func schedule() {
    guard notificationManager.settings.enabled else {
      statusMessage = "Turn on reminders first."
      notificationManager.scheduleNotifications()
      return
    }

    switch notificationManager.authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      notificationManager.scheduleNotifications()
      statusMessage = "Reminder saved."
    case .denied:
      statusMessage = "Notifications are blocked in iOS Settings."
    case .notDetermined:
      notificationManager.requestAuthorizationAndSchedule()
      statusMessage = "Notification permission requested."
    @unknown default:
      notificationManager.requestAuthorizationAndSchedule()
      statusMessage = "Notification permission requested."
    }
  }
}
