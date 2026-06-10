import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
  @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
  @Published private(set) var settings: ReviewReminderSettings = ReviewReminderSettings() {
    didSet { saveSettings() }
  }

  private let center = UNUserNotificationCenter.current()
  private let settingsKey = "flashcard_generator_reminder_settings_v1"
  private let identifierPrefix = "flashcard-generator-review-reminder"

  init() {}

  func prepareIfNeeded() {
    loadSettings()
    refreshAuthorizationStatus()
  }

  var reminderDate: Date {
    let calendar = Calendar.current
    let base = calendar.startOfDay(for: Date())
    return calendar.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: base) ?? Date()
  }

  var authorizationText: String {
    switch authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      return "Notifications enabled"
    case .denied:
      return "Notifications blocked in Settings"
    case .notDetermined:
      return "Notifications not requested"
    @unknown default:
      return "Notification status unavailable"
    }
  }

  func updateSettings(_ update: (inout ReviewReminderSettings) -> Void) {
    var copy = settings
    update(&copy)
    settings = copy
  }

  func setReminderDate(_ date: Date) {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    updateSettings {
      $0.hour = components.hour ?? 19
      $0.minute = components.minute ?? 0
    }
  }

  func toggleWeekday(_ weekday: Int) {
    updateSettings {
      if $0.weekdays.contains(weekday) {
        $0.weekdays.remove(weekday)
      } else {
        $0.weekdays.insert(weekday)
      }
    }
  }

  func refreshAuthorizationStatus() {
    center.getNotificationSettings { [weak self] settings in
      Task { @MainActor in
        self?.authorizationStatus = settings.authorizationStatus
      }
    }
  }

  func requestAuthorizationAndSchedule() {
    center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
      Task { @MainActor in
        self?.authorizationStatus = granted ? .authorized : .denied
        if granted {
          self?.scheduleNotifications()
        } else {
          self?.removeScheduledNotifications()
        }
      }
    }
  }

  func scheduleNotifications() {
    removeScheduledNotifications()
    guard settings.enabled else { return }

    if settings.weekdays.isEmpty {
      addNotification(identifier: "\(identifierPrefix)-daily", weekday: nil)
    } else {
      for weekday in settings.weekdays.sorted() {
        addNotification(identifier: "\(identifierPrefix)-\(weekday)", weekday: weekday)
      }
    }
  }

  func removeScheduledNotifications() {
    let identifiers = ["\(identifierPrefix)-daily"] + (1...7).map { "\(identifierPrefix)-\($0)" }
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
  }

  private func addNotification(identifier: String, weekday: Int?) {
    let content = UNMutableNotificationContent()
    content.title = "Review Mandarin flashcards"
    content.body = "Your due words are ready."
    content.sound = .default

    var dateComponents = DateComponents()
    dateComponents.hour = settings.hour
    dateComponents.minute = settings.minute
    dateComponents.weekday = weekday

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    center.add(request)
  }

  private func loadSettings() {
    guard let data = UserDefaults.standard.data(forKey: settingsKey) else { return }
    guard let decoded = try? JSONDecoder().decode(ReviewReminderSettings.self, from: data) else { return }
    settings = decoded
  }

  private func saveSettings() {
    guard let encoded = try? JSONEncoder().encode(settings) else { return }
    UserDefaults.standard.set(encoded, forKey: settingsKey)
  }
}
