import Combine
import Foundation

@MainActor
final class StudyStore: ObservableObject {
  @Published private(set) var terms: [FlashcardTerm] = [] {
    didSet { save() }
  }

  private let storageKey = "flashcard_generator_terms_v1"
  private static let bundledGlossaryResourceNames = ["StarterGlossary", "TennisGlossary"]
  private var isLoading = false
  private var hasPreparedInitialData = false

  init() {}

  func prepareInitialDataIfNeeded() {
    guard !hasPreparedInitialData else { return }
    hasPreparedInitialData = true

    isLoading = true
    load()
    isLoading = false
    mergeBundledGlossaries()
  }

  var units: [UnitSection] {
    Dictionary(grouping: terms, by: \.unit)
      .map { UnitSection(name: $0.key, terms: $0.value.sorted { $0.number < $1.number }) }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  var dueCount: Int {
    dueTerms().count
  }

  var swampCount: Int {
    swampTerms().count
  }

  var masteredCount: Int {
    terms.filter { $0.review.repetitions >= 3 && $0.review.lapses == 0 }.count
  }

  func importGlossary(_ rawText: String, merge: Bool) throws -> Int {
    let parsed = try GlossaryParser.parse(rawText)

    if merge {
      var merged = terms

      for imported in parsed {
        if let index = merged.firstIndex(where: { $0.unit == imported.unit && $0.number == imported.number }) {
          var updated = imported
          updated.id = merged[index].id
          updated.review = merged[index].review
          merged[index] = updated
        } else {
          merged.append(imported)
        }
      }

      terms = sortTerms(merged)
    } else {
      terms = sortTerms(parsed)
    }

    return parsed.count
  }

  func addManualTerm(unit: String, term: String, pinyin: String, partOfSpeech: String, englishMeaning: String) {
    let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPinyin = pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPartOfSpeech = partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedMeaning = englishMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
    let nextNumber = ((terms.filter { $0.unit == trimmedUnit }.map(\.number).max()) ?? 0) + 1
    let definition = [trimmedPartOfSpeech, trimmedMeaning]
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    terms = sortTerms(terms + [
      FlashcardTerm(
        unit: trimmedUnit,
        number: nextNumber,
        term: trimmedTerm,
        pinyin: trimmedPinyin,
        definition: definition,
        usage: ""
      )
    ])
  }

  static func starterGlossaryText() -> String? {
    bundledGlossaryText(named: "StarterGlossary")
  }

  static func providedGlossaryText() -> String? {
    let texts = bundledGlossaryResourceNames.compactMap { bundledGlossaryText(named: $0) }
    guard !texts.isEmpty else { return nil }
    return texts.joined(separator: "\n\n")
  }

  func dueTerms(in unit: String? = nil) -> [FlashcardTerm] {
    let now = Date()
    return terms
      .filter { unit == nil || $0.unit == unit }
      .filter { $0.review.dueDate <= now }
      .sorted {
        if $0.review.dueDate == $1.review.dueDate {
          return $0.number < $1.number
        }
        return $0.review.dueDate < $1.review.dueDate
      }
  }

  func allTerms(in unit: String? = nil) -> [FlashcardTerm] {
    terms
      .filter { unit == nil || $0.unit == unit }
      .sorted {
        if $0.unit == $1.unit {
          return $0.number < $1.number
        }
        return $0.unit.localizedStandardCompare($1.unit) == .orderedAscending
      }
  }

  func swampTerms(in unit: String? = nil) -> [FlashcardTerm] {
    terms
      .filter { unit == nil || $0.unit == unit }
      .filter { $0.review.swampAddedAt != nil }
      .sorted {
        switch ($0.review.swampAddedAt, $1.review.swampAddedAt) {
        case let (left?, right?) where left != right:
          return left < right
        default:
          if $0.unit == $1.unit {
            return $0.number < $1.number
          }
          return $0.unit.localizedStandardCompare($1.unit) == .orderedAscending
        }
      }
  }

  func term(with id: UUID) -> FlashcardTerm? {
    terms.first { $0.id == id }
  }

  func recordReview(for id: UUID, grade: ReviewGrade) {
    guard let index = terms.firstIndex(where: { $0.id == id }) else { return }

    var term = terms[index]
    term.review = scheduleReview(from: term.review, grade: grade)
    terms[index] = term
  }

  func addToSwamp(id: UUID) {
    guard let index = terms.firstIndex(where: { $0.id == id }) else { return }

    var term = terms[index]
    if term.review.swampAddedAt == nil {
      term.review.swampAddedAt = Date()
      terms[index] = term
    }
  }

  func removeFromSwamp(id: UUID) {
    guard let index = terms.firstIndex(where: { $0.id == id }) else { return }

    var term = terms[index]
    if term.review.swampAddedAt != nil {
      term.review.swampAddedAt = nil
      terms[index] = term
    }
  }

  func resetProgress() {
    terms = terms.map { term in
      var updated = term
      updated.review = ReviewState()
      return updated
    }
  }

  func deleteTerms(at offsets: IndexSet, in unit: String) {
    let unitTerms = allTerms(in: unit)
    let idsToDelete = Set(offsets.map { unitTerms[$0].id })
    terms.removeAll { idsToDelete.contains($0.id) }
  }

  private func scheduleReview(from review: ReviewState, grade: ReviewGrade) -> ReviewState {
    var updated = review
    let now = Date()
    updated.lastReviewed = now

    switch grade {
    case .forgot:
      updated.repetitions = 0
      updated.lapses += 1
      updated.intervalDays = 10.0 / (24.0 * 60.0)
      updated.easeFactor = max(1.3, updated.easeFactor - 0.2)
    case .unsure:
      updated.repetitions = max(1, updated.repetitions)
      updated.intervalDays = max(0.5, updated.intervalDays * 0.6)
      updated.easeFactor = max(1.3, updated.easeFactor - 0.05)
    case .absolutelySure:
      updated.repetitions += 1
      updated.easeFactor = min(3.0, updated.easeFactor + 0.08)

      if updated.repetitions == 1 {
        updated.intervalDays = 1
      } else if updated.repetitions == 2 {
        updated.intervalDays = 3
      } else {
        updated.intervalDays = max(1, updated.intervalDays * updated.easeFactor)
      }
    }

    updated.dueDate = now.addingTimeInterval(updated.intervalDays * 24 * 60 * 60)
    return updated
  }

  private func sortTerms(_ values: [FlashcardTerm]) -> [FlashcardTerm] {
    values.sorted { left, right in
      if left.unit == right.unit {
        return left.number < right.number
      }
      return left.unit.localizedStandardCompare(right.unit) == .orderedAscending
    }
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
    guard let decoded = try? JSONDecoder().decode([FlashcardTerm].self, from: data) else { return }
    terms = decoded
  }

  private static func bundledGlossaryText(named resourceName: String) -> String? {
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "txt") else {
      return nil
    }

    return try? String(contentsOf: url, encoding: .utf8)
  }

  private static func bundledGlossaryTexts() -> [String] {
    bundledGlossaryResourceNames.compactMap { bundledGlossaryText(named: $0) }
  }

  private func mergeBundledGlossaries() {
    var merged = terms
    var didChange = false

    for text in Self.bundledGlossaryTexts() {
      guard let parsed = try? GlossaryParser.parse(text) else { continue }

      for imported in parsed {
        if let index = bundledMatchIndex(for: imported, in: merged) {
          var updated = imported
          updated.id = merged[index].id
          updated.review = merged[index].review

          if merged[index] != updated {
            merged[index] = updated
            didChange = true
          }
        } else {
          merged.append(imported)
          didChange = true
        }
      }
    }

    if didChange {
      terms = sortTerms(merged)
    }
  }

  private func bundledMatchIndex(for imported: FlashcardTerm, in values: [FlashcardTerm]) -> Int? {
    values.firstIndex { existing in
      existing.unit == imported.unit && existing.term == imported.term
    }
  }

  private func save() {
    guard !isLoading else { return }
    guard let encoded = try? JSONEncoder().encode(terms) else { return }
    UserDefaults.standard.set(encoded, forKey: storageKey)
  }
}
