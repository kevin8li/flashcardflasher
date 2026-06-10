import Foundation

enum ReviewGrade: String, Codable, CaseIterable, Identifiable {
  case forgot
  case unsure
  case absolutelySure

  var id: String { rawValue }

  var title: String {
    switch self {
    case .forgot: return "Forgot"
    case .unsure: return "Unsure"
    case .absolutelySure: return "Absolutely Sure"
    }
  }
}

struct ReviewState: Codable, Equatable {
  var dueDate: Date
  var intervalDays: Double
  var easeFactor: Double
  var repetitions: Int
  var lapses: Int
  var lastReviewed: Date?
  var swampAddedAt: Date?

  init(
    dueDate: Date = Date(),
    intervalDays: Double = 0,
    easeFactor: Double = 2.5,
    repetitions: Int = 0,
    lapses: Int = 0,
    lastReviewed: Date? = nil,
    swampAddedAt: Date? = nil
  ) {
    self.dueDate = dueDate
    self.intervalDays = intervalDays
    self.easeFactor = easeFactor
    self.repetitions = repetitions
    self.lapses = lapses
    self.lastReviewed = lastReviewed
    self.swampAddedAt = swampAddedAt
  }
}

struct FlashcardExample: Identifiable, Codable, Equatable {
  var id: UUID
  var chinese: String
  var pinyin: String
  var english: String

  init(
    id: UUID = UUID(),
    chinese: String,
    pinyin: String,
    english: String
  ) {
    self.id = id
    self.chinese = chinese
    self.pinyin = pinyin
    self.english = english
  }
}

struct FlashcardTerm: Identifiable, Codable, Equatable {
  var id: UUID
  var unit: String
  var number: Int
  var term: String
  var pinyin: String
  var definition: String
  var usage: String
  var examples: [FlashcardExample]
  var review: ReviewState

  init(
    id: UUID = UUID(),
    unit: String,
    number: Int,
    term: String,
    pinyin: String,
    definition: String,
    usage: String,
    examples: [FlashcardExample] = [],
    review: ReviewState = ReviewState()
  ) {
    self.id = id
    self.unit = unit
    self.number = number
    self.term = term
    self.pinyin = pinyin
    self.definition = definition
    self.usage = usage
    self.examples = examples
    self.review = review
  }

  enum CodingKeys: String, CodingKey {
    case id
    case unit
    case number
    case term
    case pinyin
    case definition
    case usage
    case examples
    case review
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    unit = try container.decode(String.self, forKey: .unit)
    number = try container.decode(Int.self, forKey: .number)
    term = try container.decode(String.self, forKey: .term)
    pinyin = try container.decode(String.self, forKey: .pinyin)
    definition = try container.decode(String.self, forKey: .definition)
    usage = try container.decode(String.self, forKey: .usage)
    examples = try container.decodeIfPresent([FlashcardExample].self, forKey: .examples) ?? []
    review = try container.decode(ReviewState.self, forKey: .review)
  }
}

struct UnitSection: Identifiable, Equatable {
  var id: String { name }
  let name: String
  let terms: [FlashcardTerm]

  var dueCount: Int {
    terms.filter { $0.review.dueDate <= Date() }.count
  }

  var swampCount: Int {
    terms.filter { $0.review.swampAddedAt != nil }.count
  }
}

struct ReviewReminderSettings: Codable, Equatable {
  var enabled: Bool = false
  var hour: Int = 19
  var minute: Int = 0
  var weekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
}

enum GlossaryImportError: LocalizedError {
  case noTermsFound

  var errorDescription: String? {
    switch self {
    case .noTermsFound:
      return "No valid terms were found. Use columns for Unit, Chinese, Pinyin, Type, and English. A word number column is optional."
    }
  }
}
