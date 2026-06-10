import SwiftUI

struct ImportView: View {
  @EnvironmentObject private var store: StudyStore

  @State private var inputText = ""
  @State private var mergeExisting = true
  @State private var statusMessage: String?
  @State private var errorMessage: String?
  @State private var showResetConfirmation = false

  private let template = """
Unit 1
Number\tTerm\tPinyin\tPart of Speech\tEnglish Meaning\tChinese Sentence\tPinyin Sentence\tEnglish Translation
1\t词语\tcíyǔ\tn.\tword; term\t这个词语很常用。\tZhège cíyǔ hěn chángyòng.\tThis term is commonly used.
2\t短语\tduǎnyǔ\tn.\tphrase\t请写一个短语。\tQǐng xiě yí ge duǎnyǔ.\tPlease write a phrase.

Unit 2
1\t例子\tlìzi\tn.\texample\t这个例子很清楚。\tZhège lìzi hěn qīngchu.\tThis example is clear.
"""

  var body: some View {
    NavigationStack {
      AppScreen {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            AppHeader(
              section: "Import",
              detail: "Manage glossary decks",
              systemImage: "square.and.arrow.down"
            )
            header
            importPanel
            libraryPanel
          }
          .padding()
          .frame(maxWidth: .infinity)
        }
      }
      .navigationTitle("Flashcards")
      .alert("Import issue", isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "")
      }
      .confirmationDialog("Reset all review progress?", isPresented: $showResetConfirmation) {
        Button("Reset Progress", role: .destructive) {
          store.resetProgress()
          statusMessage = "Review progress reset."
        }
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        StatTile(
          title: "Terms",
          value: "\(store.terms.count)",
          systemImage: "character.book.closed",
          color: AppTheme.teal
        )

        StatTile(
          title: "Due",
          value: "\(store.dueCount)",
          systemImage: "clock.badge.exclamationmark",
          color: AppTheme.coral
        )
      }

      HStack(spacing: 12) {
        StatTile(
          title: "Units",
          value: "\(store.units.count)",
          systemImage: "rectangle.stack.badge.person.crop",
          color: AppTheme.gold
        )

        StatTile(
          title: "Strong",
          value: "\(store.masteredCount)",
          systemImage: "checkmark.seal",
          color: .green
        )
      }
    }
  }

  private var importPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Glossary Table", systemImage: "tablecells")
          .font(.headline)
          .foregroundStyle(AppTheme.ink)

        Spacer()

        HStack(spacing: 12) {
          Button("Provided") {
            loadStarterGlossary()
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AppTheme.teal)

          Button("Template") {
            inputText = template
            statusMessage = nil
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AppTheme.teal)
        }
      }

      Text("Unit, Chinese, Pinyin, Part of Speech, English Meaning. Add example Chinese, Pinyin, and English columns when available.")
        .font(.caption)
        .foregroundStyle(AppTheme.muted)

      ZStack(alignment: .topLeading) {
        TextEditor(text: $inputText)
          .font(.body.monospaced())
          .foregroundStyle(AppTheme.ink)
          .scrollContentBackground(.hidden)
          .padding(8)
          .frame(minHeight: 260)

        if inputText.isEmpty {
          Text("Paste a tab, pipe, or CSV glossary table.")
            .font(.body)
            .foregroundStyle(AppTheme.muted.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .allowsHitTesting(false)
        }
      }
      .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(AppTheme.border)
      )

      Toggle("Merge with existing terms", isOn: $mergeExisting)
        .tint(AppTheme.teal)

      PrimaryActionButton(title: "Import Glossary", systemImage: "tray.and.arrow.down", color: AppTheme.teal) {
        importGlossary()
      }

      if let statusMessage {
        Label(statusMessage, systemImage: "checkmark.circle.fill")
          .font(.subheadline)
          .foregroundStyle(.green)
      }
    }
    .padding(16)
    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
  }

  private var libraryPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Library", systemImage: "books.vertical")
          .font(.headline)
          .foregroundStyle(AppTheme.ink)

        Spacer()

        Button("Reset") {
          showResetConfirmation = true
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.coral)
        .disabled(store.terms.isEmpty)
      }

      ForEach(store.units.prefix(4)) { unit in
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(unit.name)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(AppTheme.ink)
            Text("\(unit.terms.count) terms")
              .font(.caption)
              .foregroundStyle(AppTheme.muted)
          }

          Spacer()

          PillLabel(text: "\(unit.dueCount) due", color: unit.dueCount > 0 ? AppTheme.coral : AppTheme.teal)
        }
        .padding(.vertical, 4)
      }

      if store.units.isEmpty {
        Text("No glossary imported yet.")
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

  private func importGlossary() {
    do {
      let count = try store.importGlossary(inputText, merge: mergeExisting)
      statusMessage = "Imported \(count) terms."
      errorMessage = nil
    } catch {
      statusMessage = nil
      errorMessage = error.localizedDescription
    }
  }

  private func loadStarterGlossary() {
    guard let text = StudyStore.providedGlossaryText() else {
      errorMessage = "The provided glossary file could not be loaded."
      return
    }

    inputText = text
    let count = (try? GlossaryParser.parse(text).count) ?? 0
    statusMessage = "Loaded provided \(count)-word glossary."
    errorMessage = nil
  }
}
