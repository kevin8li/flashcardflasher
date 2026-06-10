import SwiftUI

struct ReviewView: View {
  @EnvironmentObject private var store: StudyStore

  @State private var selectedUnit: String?
  @State private var activeReviewSet: ReviewSet = .due
  @State private var queue: [UUID] = []
  @State private var moreToReviewIds: [UUID] = []
  @State private var revealStage = 0
  @State private var reviewedThisSession = 0

  private var currentTerm: FlashcardTerm? {
    guard let id = queue.first else { return nil }
    return store.term(with: id)
  }

  private var moreToReviewCount: Int {
    moreToReviewIds.filter { termMatchesSelectedUnit($0) }.count
  }

  private var swampCount: Int {
    store.swampTerms(in: selectedUnit).count
  }

  var body: some View {
    NavigationStack {
      AppScreen {
        GeometryReader { proxy in
          VStack(spacing: 8) {
            AppHeader(
              section: "Review",
              detail: "\(store.dueCount) due · \(store.swampCount) swamp",
              systemImage: "rectangle.on.rectangle.angled"
            )

            if store.terms.isEmpty {
              Spacer(minLength: 0)
              EmptyStateView(
                title: "No cards to review",
                subtitle: "Import a glossary to create a review deck.",
                systemImage: "rectangle.on.rectangle.slash"
              )
              Spacer(minLength: 0)
            } else if let currentTerm {
              reviewHeader

              ReviewCard(
                term: currentTerm,
                revealStage: revealStage,
                onSwipeForward: advanceReveal,
                onSwipeBack: retreatReveal
              )
              .overlay(alignment: .leading) {
                if revealStage < currentRevealLimit {
                  sideArrowButton(
                    systemImage: "chevron.left",
                    color: AppTheme.ink,
                    disabled: revealStage == 0,
                    action: retreatReveal
                  )
                  .padding(.leading, 6)
                  .offset(y: 76)
                }
              }
              .overlay(alignment: .trailing) {
                if revealStage < currentRevealLimit {
                  sideArrowButton(
                    systemImage: "chevron.right",
                    color: AppTheme.teal,
                    disabled: false,
                    action: advanceReveal
                  )
                  .padding(.trailing, 6)
                  .offset(y: 76)
                }
              }
              .layoutPriority(1)

              if revealStage >= currentRevealLimit {
                gradeButtons
              } else {
                revealButton
              }
            } else {
              reviewHeader
              Spacer(minLength: 0)
              sessionEmptyState
              Spacer(minLength: 0)
            }
          }
          .padding(.horizontal, 12)
          .padding(.top, 8)
          .padding(.bottom, 6)
          .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
      }
      .navigationTitle("Review")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        if queue.isEmpty {
          startDueSession()
        }
      }
      .onChange(of: selectedUnit) {
        rebuildActiveSession()
      }
    }
  }

  private var revealButton: some View {
    PrimaryActionButton(
      title: nextRevealTitle,
      systemImage: nextRevealSystemImage,
      color: AppTheme.teal
    ) {
      advanceReveal()
    }
  }

  private func sideArrowButton(
    systemImage: String,
    color: Color,
    disabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.title3.weight(.bold))
        .frame(width: 46, height: 58)
    }
    .buttonStyle(ArrowControlButtonStyle(color: color))
    .disabled(disabled)
    .opacity(disabled ? 0.32 : 1)
  }

  private var currentRevealLimit: Int {
    currentTerm?.revealItems.count ?? 2
  }

  private var nextRevealTitle: String {
    guard let item = currentTerm?.revealItems[safe: revealStage] else {
      return "Show Next"
    }

    return "Show \(item.label)"
  }

  private var nextRevealSystemImage: String {
    guard let item = currentTerm?.revealItems[safe: revealStage] else {
      return "arrow.right.circle"
    }

    switch item.kind {
    case .pinyin:
      return "textformat"
    case .definition:
      return "text.book.closed"
    case .exampleChinese:
      return "character.bubble"
    case .examplePinyin:
      return "quote.bubble"
    case .exampleEnglish:
      return "translate"
    }
  }

  private var reviewHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Picker("Unit", selection: $selectedUnit) {
          Text("All Units").tag(String?.none)
          ForEach(store.units) { unit in
            Text(unit.name).tag(Optional(unit.name))
          }
        }
        .pickerStyle(.menu)
        .tint(AppTheme.teal)

        Spacer(minLength: 0)

        PillLabel(text: "\(queue.count) left", color: AppTheme.teal)
      }

      HStack(spacing: 6) {
        modeButton(.due, title: "Due", count: store.dueTerms(in: selectedUnit).count, systemImage: "clock", color: AppTheme.teal) {
          startDueSession()
        }

        modeButton(.all, title: "All", count: store.allTerms(in: selectedUnit).count, systemImage: "rectangle.stack", color: AppTheme.ink) {
          startAllSession()
        }

        modeButton(.more, title: "More", count: moreToReviewCount, systemImage: "arrow.triangle.2.circlepath", color: AppTheme.coral) {
          startMoreToReviewSession()
        }
        .disabled(moreToReviewCount == 0)

        modeButton(.swamp, title: "Swamp", count: swampCount, systemImage: "tray.full", color: AppTheme.gold) {
          startSwampSession()
        }
        .disabled(swampCount == 0)
      }
    }
    .padding(10)
    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
  }

  private func modeButton(
    _ reviewSet: ReviewSet,
    title: String,
    count: Int,
    systemImage: String,
    color: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Label(title, systemImage: systemImage)
          .font(.caption.weight(.bold))
          .lineLimit(1)
          .minimumScaleFactor(0.64)

        Text("\(count)")
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(ReviewModeButtonStyle(color: color, active: activeReviewSet == reviewSet))
  }

  private var sessionEmptyState: some View {
    VStack(spacing: 12) {
      EmptyStateView(
        title: reviewedThisSession == 0 ? "Nothing due" : "Session complete",
        subtitle: reviewedThisSession == 0 ? "Start all cards for extra practice." : "Forgot and Unsure cards were repeated during this session.",
        systemImage: reviewedThisSession == 0 ? "checkmark.circle" : "sparkles"
      )

      PrimaryActionButton(title: "Review All Cards", systemImage: "rectangle.stack", color: AppTheme.teal) {
        startAllSession()
      }
    }
  }

  private var gradeButtons: some View {
    HStack(spacing: 8) {
      Button {
        grade(.absolutelySure)
      } label: {
        Label("Absolutely Sure", systemImage: "checkmark.circle")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(ReviewControlButtonStyle(color: AppTheme.teal))

      Button {
        grade(.unsure)
      } label: {
        Label("Unsure", systemImage: "questionmark.circle")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(ReviewControlButtonStyle(color: AppTheme.gold))

      Button {
        grade(.forgot)
      } label: {
        Label("Forgot", systemImage: "xmark.circle")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(ReviewControlButtonStyle(color: AppTheme.coral))
    }
  }

  private func startDueSession() {
    activeReviewSet = .due
    queue = store.dueTerms(in: selectedUnit).map(\.id)
    reviewedThisSession = 0
    revealStage = 0
  }

  private func startAllSession() {
    activeReviewSet = .all
    queue = store.allTerms(in: selectedUnit).map(\.id)
    reviewedThisSession = 0
    revealStage = 0
  }

  private func startMoreToReviewSession() {
    activeReviewSet = .more
    queue = moreToReviewIds.filter { termMatchesSelectedUnit($0) }
    reviewedThisSession = 0
    revealStage = 0
  }

  private func startSwampSession() {
    activeReviewSet = .swamp
    queue = store.swampTerms(in: selectedUnit).map(\.id)
    reviewedThisSession = 0
    revealStage = 0
  }

  private func rebuildActiveSession() {
    switch activeReviewSet {
    case .due:
      queue = store.dueTerms(in: selectedUnit).map(\.id)
    case .all:
      queue = store.allTerms(in: selectedUnit).map(\.id)
    case .more:
      queue = moreToReviewIds.filter { termMatchesSelectedUnit($0) }
    case .swamp:
      queue = store.swampTerms(in: selectedUnit).map(\.id)
    }

    reviewedThisSession = 0
    revealStage = 0
  }

  private func advanceReveal() {
    if revealStage >= currentRevealLimit {
      grade(.absolutelySure)
      return
    }

    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
      revealStage = min(revealStage + 1, currentRevealLimit)
    }
  }

  private func retreatReveal() {
    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
      revealStage = max(revealStage - 1, 0)
    }
  }

  private func grade(_ grade: ReviewGrade) {
    guard let id = queue.first else { return }

    queue.removeFirst()
    store.recordReview(for: id, grade: grade)
    reviewedThisSession += 1

    switch grade {
    case .forgot:
      markForMoreReview(id)
      store.addToSwamp(id: id)
      repeatLater(id)
    case .unsure:
      markForMoreReview(id)
      repeatLater(id)
    case .absolutelySure:
      moreToReviewIds.removeAll { $0 == id }
      if activeReviewSet == .swamp {
        store.removeFromSwamp(id: id)
      }
    }

    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
      revealStage = 0
    }
  }

  private func markForMoreReview(_ id: UUID) {
    if !moreToReviewIds.contains(id) {
      moreToReviewIds.append(id)
    }
  }

  private func repeatLater(_ id: UUID) {
    let offset = Int.random(in: 3...10)
    let insertionIndex = min(offset, queue.count)
    queue.insert(id, at: insertionIndex)
  }

  private func termMatchesSelectedUnit(_ id: UUID) -> Bool {
    guard let term = store.term(with: id) else { return false }
    guard let selectedUnit else { return true }
    return term.unit == selectedUnit
  }
}

private enum ReviewSet: Equatable {
  case due
  case all
  case more
  case swamp
}

private enum RevealItemKind {
  case pinyin
  case definition
  case exampleChinese
  case examplePinyin
  case exampleEnglish
}

private struct RevealItem: Identifiable {
  let id: RevealItemKind
  let kind: RevealItemKind
  let label: String
  let text: String
  let color: Color
  let font: Font
  let lineLimit: Int
}

private extension FlashcardTerm {
  var primaryExample: FlashcardExample? {
    examples.first
  }

  var revealItems: [RevealItem] {
    var items = [
      RevealItem(
        id: .pinyin,
        kind: .pinyin,
        label: "Pinyin",
        text: pinyin,
        color: AppTheme.teal,
        font: .body.weight(.semibold),
        lineLimit: 2
      ),
      RevealItem(
        id: .definition,
        kind: .definition,
        label: "Definition",
        text: definition,
        color: AppTheme.ink,
        font: .body.weight(.semibold),
        lineLimit: 3
      )
    ]

    if let primaryExample {
      if !primaryExample.chinese.isEmpty {
        items.append(
          RevealItem(
            id: .exampleChinese,
            kind: .exampleChinese,
            label: "Example Chinese",
            text: primaryExample.chinese,
            color: AppTheme.ink,
            font: .callout.weight(.semibold),
            lineLimit: 3
          )
        )
      }

      if !primaryExample.pinyin.isEmpty {
        items.append(
          RevealItem(
            id: .examplePinyin,
            kind: .examplePinyin,
            label: "Example Pinyin",
            text: primaryExample.pinyin,
            color: AppTheme.teal,
            font: .callout,
            lineLimit: 3
          )
        )
      }

      if !primaryExample.english.isEmpty {
        items.append(
          RevealItem(
            id: .exampleEnglish,
            kind: .exampleEnglish,
            label: "Example English",
            text: primaryExample.english,
            color: AppTheme.muted,
            font: .callout,
            lineLimit: 3
          )
        )
      }
    } else if !usage.isEmpty {
      items.append(
        RevealItem(
          id: .exampleChinese,
          kind: .exampleChinese,
          label: "Usage",
          text: usage,
          color: AppTheme.muted,
          font: .callout,
          lineLimit: 3
        )
      )
    }

    return items
  }
}

private extension Collection {
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

private struct ReviewCard: View {
  let term: FlashcardTerm
  let revealStage: Int
  let onSwipeForward: () -> Void
  let onSwipeBack: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        PillLabel(text: term.unit, color: AppTheme.teal)
        Spacer()
        PillLabel(text: "#\(term.number)", color: AppTheme.gold)
      }

      Spacer(minLength: 8)

      CardAnswerSection(
        label: "Chinese",
        text: term.term,
        color: AppTheme.ink,
        font: .system(size: 40, weight: .bold, design: .rounded),
        lineLimit: 2
      )

      if revealStage > 0 {
        VStack(spacing: 8) {
          ForEach(Array(term.revealItems.prefix(revealStage))) { item in
            CardAnswerSection(
              label: item.label,
              text: item.text,
              color: item.color,
              font: item.font,
              lineLimit: item.lineLimit
            )
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxHeight: .infinity)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      Spacer(minLength: 8)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      LinearGradient(
        colors: [Color.white, Color(red: 0.91, green: 0.96, blue: 0.94)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 8)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
    .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 32)
        .onEnded { value in
          guard abs(value.translation.width) > abs(value.translation.height) else { return }

          if value.translation.width < -44 {
            onSwipeForward()
          } else if value.translation.width > 44 {
            onSwipeBack()
          }
        }
    )
  }
}

private struct CardAnswerSection: View {
  let label: String
  let text: String
  let color: Color
  let font: Font
  let lineLimit: Int

  var body: some View {
    VStack(spacing: 4) {
      Text(label)
        .font(.caption2.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(AppTheme.muted)

      Text(text)
        .font(font)
        .foregroundStyle(color)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.52)
        .lineLimit(lineLimit)
        .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 3)
  }
}

private struct ReviewControlButtonStyle: ButtonStyle {
  let color: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.white)
      .lineLimit(1)
      .minimumScaleFactor(0.72)
      .padding(.vertical, 11)
      .padding(.horizontal, 8)
      .background(color.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct ArrowControlButtonStyle: ButtonStyle {
  let color: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(color)
      .background(
        color.opacity(configuration.isPressed ? 0.18 : 0.10),
        in: RoundedRectangle(cornerRadius: 8)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(color.opacity(0.22))
      )
      .opacity(configuration.isPressed ? 0.86 : 1)
  }
}

private struct ReviewModeButtonStyle: ButtonStyle {
  let color: Color
  let active: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(active ? .white : color)
      .padding(.vertical, 7)
      .padding(.horizontal, 4)
      .background(
        active ? color.opacity(configuration.isPressed ? 0.82 : 1) : color.opacity(configuration.isPressed ? 0.18 : 0.10),
        in: RoundedRectangle(cornerRadius: 8)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(active ? color : color.opacity(0.24))
      )
  }
}
