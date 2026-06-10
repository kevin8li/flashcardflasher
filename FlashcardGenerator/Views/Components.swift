import SwiftUI

enum AppTheme {
  static let background = Color(red: 0.96, green: 0.97, blue: 0.95)
  static let surface = Color.white
  static let ink = Color(red: 0.10, green: 0.13, blue: 0.15)
  static let muted = Color(red: 0.42, green: 0.46, blue: 0.48)
  static let teal = Color(red: 0.05, green: 0.44, blue: 0.42)
  static let coral = Color(red: 0.82, green: 0.28, blue: 0.22)
  static let gold = Color(red: 0.87, green: 0.61, blue: 0.18)
  static let border = Color.black.opacity(0.08)
}

struct AppScreen<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ZStack {
      AppTheme.background.ignoresSafeArea()
      content
    }
  }
}

struct AppHeader: View {
  let section: String
  let detail: String
  let systemImage: String

  init(section: String, detail: String, systemImage: String = "character.book.closed") {
    self.section = section
    self.detail = detail
    self.systemImage = systemImage
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .frame(width: 42, height: 42)
        .background(AppTheme.teal, in: RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 2) {
        Text("凯文卡")
          .font(.title2.weight(.bold))
          .foregroundStyle(AppTheme.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.72)

        Text("\(section) · \(detail)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(AppTheme.muted)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }

      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(maxWidth: .infinity)
    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
  }
}

struct StatTile: View {
  let title: String
  let value: String
  let systemImage: String
  let color: Color

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.headline)
        .foregroundStyle(color)
        .frame(width: 34, height: 34)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 2) {
        Text(value)
          .font(.title3.weight(.bold))
          .foregroundStyle(AppTheme.ink)
        Text(title)
          .font(.caption)
          .foregroundStyle(AppTheme.muted)
      }

      Spacer(minLength: 0)
    }
    .padding(12)
    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
  }
}

struct PillLabel: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(color)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(color.opacity(0.12), in: Capsule())
  }
}

struct EmptyStateView: View {
  let title: String
  let subtitle: String
  let systemImage: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 44, weight: .semibold))
        .foregroundStyle(AppTheme.teal)

      Text(title)
        .font(.headline)
        .foregroundStyle(AppTheme.ink)

      Text(subtitle)
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .foregroundStyle(AppTheme.muted)
        .padding(.horizontal)
    }
    .frame(maxWidth: .infinity)
    .padding(28)
    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
    .padding(.horizontal)
  }
}

struct PrimaryActionButton: View {
  let title: String
  let systemImage: String
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .background(color, in: RoundedRectangle(cornerRadius: 8))
  }
}
