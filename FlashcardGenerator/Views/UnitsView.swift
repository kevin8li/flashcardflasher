import SwiftUI

struct UnitsView: View {
  @EnvironmentObject private var store: StudyStore

  var body: some View {
    NavigationStack {
      AppScreen {
        if store.units.isEmpty {
          VStack(spacing: 16) {
            AppHeader(
              section: "Units",
              detail: "\(store.terms.count) terms organized",
              systemImage: "rectangle.stack"
            )

            Spacer(minLength: 0)

            EmptyStateView(
              title: "No units yet",
              subtitle: "Imported glossary units will appear here.",
              systemImage: "rectangle.stack.badge.plus"
            )

            Spacer(minLength: 0)
          }
          .padding()
        } else {
          ScrollView {
            VStack(spacing: 12) {
              AppHeader(
                section: "Units",
                detail: "\(store.terms.count) terms organized",
                systemImage: "rectangle.stack"
              )

              ForEach(store.units) { unit in
                NavigationLink {
                  UnitDetailView(unitName: unit.name)
                } label: {
                  UnitRow(unit: unit)
                }
                .buttonStyle(.plain)
              }
            }
            .padding()
            .frame(maxWidth: .infinity)
          }
        }
      }
      .navigationTitle("Units")
    }
  }
}

private struct UnitRow: View {
  let unit: UnitSection

  private var reviewedCount: Int {
    unit.terms.filter { $0.review.lastReviewed != nil }.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(unit.name)
            .font(.headline)
            .foregroundStyle(AppTheme.ink)
          Text("\(unit.terms.count) terms")
            .font(.subheadline)
            .foregroundStyle(AppTheme.muted)
        }

        Spacer()

        PillLabel(
          text: unit.dueCount > 0 ? "\(unit.dueCount) due" : "clear",
          color: unit.dueCount > 0 ? AppTheme.coral : AppTheme.teal
        )
      }

      ProgressView(value: Double(reviewedCount), total: Double(max(unit.terms.count, 1)))
        .tint(AppTheme.teal)

      Text("\(reviewedCount) reviewed")
        .font(.caption)
        .foregroundStyle(AppTheme.muted)
    }
    .padding(16)
    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
  }
}

struct UnitDetailView: View {
  @EnvironmentObject private var store: StudyStore
  let unitName: String

  private var terms: [FlashcardTerm] {
    store.allTerms(in: unitName)
  }

  var body: some View {
    AppScreen {
      List {
        Section {
          ForEach(terms) { term in
            TermDetailRow(term: term)
              .listRowBackground(Color.clear)
              .listRowSeparator(.hidden)
          }
          .onDelete { offsets in
            store.deleteTerms(at: offsets, in: unitName)
          }
        }
      }
      .scrollContentBackground(.hidden)
      .listStyle(.plain)
    }
    .navigationTitle(unitName)
  }
}

private struct TermDetailRow: View {
  let term: FlashcardTerm

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text("\(term.number).")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(AppTheme.muted)

        Text(term.term)
          .font(.title2.weight(.bold))
          .foregroundStyle(AppTheme.ink)

        Spacer()

        duePill
      }

      Text(term.pinyin)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.teal)

      Text(term.definition)
        .font(.body)
        .foregroundStyle(AppTheme.ink)

      if let example = term.examples.first {
        VStack(alignment: .leading, spacing: 4) {
          if !example.chinese.isEmpty {
            Text(example.chinese)
              .font(.callout.weight(.semibold))
              .foregroundStyle(AppTheme.ink)
          }

          if !example.pinyin.isEmpty {
            Text(example.pinyin)
              .font(.caption.weight(.semibold))
              .foregroundStyle(AppTheme.teal)
          }

          if !example.english.isEmpty {
            Text(example.english)
              .font(.caption)
              .foregroundStyle(AppTheme.muted)
          }
        }
      } else if !term.usage.isEmpty {
        Text(term.usage)
          .font(.callout)
          .foregroundStyle(AppTheme.muted)
      }
    }
    .padding(14)
    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(AppTheme.border)
    )
    .padding(.vertical, 4)
  }

  private var duePill: some View {
    let isDue = term.review.dueDate <= Date()
    let text = isDue ? "due" : term.review.dueDate.formatted(date: .abbreviated, time: .omitted)
    return PillLabel(text: text, color: isDue ? AppTheme.coral : AppTheme.teal)
  }
}
