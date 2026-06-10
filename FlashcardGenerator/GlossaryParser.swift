import Foundation

enum GlossaryParser {
  static func parse(_ rawText: String) throws -> [FlashcardTerm] {
    var currentUnit = "Unit 1"
    var hasUnitHeader = false
    var columnLayout: ColumnLayout?
    var generatedNumbersByUnit: [String: Int] = [:]
    var parsed: [FlashcardTerm] = []

    for rawLine in rawText.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }

      if !hasColumnSeparator(line), let unit = detectUnitHeader(in: line) {
        currentUnit = unit
        hasUnitHeader = true
        continue
      }

      let columns = splitColumns(line)
      let meaningfulColumns = columns.filter { !$0.isEmpty }

      if let detectedLayout = ColumnLayout(headers: columns) {
        columnLayout = detectedLayout
        continue
      }

      if let columnLayout {
        let rowUnit = unitName(
          currentUnit: currentUnit,
          explicitUnit: value(at: columnLayout.unitIndex, in: columns),
          number: 1,
          allowAutomaticUnits: false
        )
        let fallbackNumber = (generatedNumbersByUnit[rowUnit] ?? 0) + 1

        if let term = parseMappedRow(
          columns,
          layout: columnLayout,
          currentUnit: currentUnit,
          fallbackNumber: fallbackNumber,
          allowAutomaticUnits: !hasUnitHeader
        ) {
          parsed.append(term)
          generatedNumbersByUnit[term.unit] = max(generatedNumbersByUnit[term.unit] ?? 0, term.number)
        }
        continue
      }

      guard meaningfulColumns.count >= 4 else { continue }
      guard !isHeaderRow(meaningfulColumns) else { continue }
      guard let number = numberValue(from: meaningfulColumns[0]) else { continue }

      let usage = meaningfulColumns.count > 4 ? meaningfulColumns[4...].joined(separator: " | ") : ""

      parsed.append(
        FlashcardTerm(
          unit: unitName(
            currentUnit: currentUnit,
            explicitUnit: nil,
            number: number,
            allowAutomaticUnits: !hasUnitHeader
          ),
          number: number,
          term: meaningfulColumns[1],
          pinyin: meaningfulColumns[2],
          definition: meaningfulColumns[3],
          usage: usage,
          examples: exampleFromUsage(usage)
        )
      )
    }

    guard !parsed.isEmpty else { throw GlossaryImportError.noTermsFound }
    return parsed.sorted { left, right in
      if left.unit.localizedStandardCompare(right.unit) == .orderedSame {
        return left.number < right.number
      }
      return left.unit.localizedStandardCompare(right.unit) == .orderedAscending
    }
  }

  private static func parseMappedRow(
    _ columns: [String],
    layout: ColumnLayout,
    currentUnit: String,
    fallbackNumber: Int,
    allowAutomaticUnits: Bool
  ) -> FlashcardTerm? {
    let number = numberValue(from: value(at: layout.numberIndex, in: columns)) ?? fallbackNumber

    let term = value(at: layout.termIndex, in: columns)
    let pinyin = value(at: layout.pinyinIndex, in: columns)
    let meaning = value(at: layout.definitionIndex, in: columns)
    let partOfSpeech = value(at: layout.partOfSpeechIndex, in: columns)
    let usage = value(at: layout.usageIndex, in: columns)
    let exampleChinese = value(at: layout.exampleChineseIndex, in: columns)
    let examplePinyin = value(at: layout.examplePinyinIndex, in: columns)
    let exampleEnglish = value(at: layout.exampleEnglishIndex, in: columns)

    guard !term.isEmpty, !pinyin.isEmpty, !meaning.isEmpty else { return nil }

    let definition = [partOfSpeech, meaning]
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    return FlashcardTerm(
      unit: unitName(
        currentUnit: currentUnit,
        explicitUnit: value(at: layout.unitIndex, in: columns),
        number: number,
        allowAutomaticUnits: allowAutomaticUnits
      ),
      number: number,
      term: term,
      pinyin: pinyin,
      definition: definition,
      usage: usage,
      examples: examples(
        usage: usage,
        chinese: exampleChinese,
        pinyin: examplePinyin,
        english: exampleEnglish
      )
    )
  }

  private static func examples(
    usage: String,
    chinese: String,
    pinyin: String,
    english: String
  ) -> [FlashcardExample] {
    let structured = FlashcardExample(
      chinese: chinese,
      pinyin: pinyin,
      english: english
    )

    if !chinese.isEmpty || !pinyin.isEmpty || !english.isEmpty {
      return [structured]
    }

    return exampleFromUsage(usage)
  }

  private static func exampleFromUsage(_ usage: String) -> [FlashcardExample] {
    let trimmed = usage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    let parts = trimmed
      .components(separatedBy: " / ")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    if parts.count >= 3 {
      return [
        FlashcardExample(
          chinese: parts[0],
          pinyin: parts[1],
          english: parts[2...].joined(separator: " / ")
        )
      ]
    }

    return [FlashcardExample(chinese: trimmed, pinyin: "", english: "")]
  }

  private static func detectUnitHeader(in line: String) -> String? {
    let cleaned = line
      .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let lowercased = cleaned.lowercased()
    let prefixes = ["unit ", "unit:", "lesson ", "lesson:", "chapter ", "chapter:"]

    if prefixes.contains(where: { lowercased.hasPrefix($0) }) {
      return cleaned
    }

    return nil
  }

  private static func splitColumns(_ line: String) -> [String] {
    if line.contains("\t") {
      return trim(line.components(separatedBy: "\t"))
    }

    if line.contains("|") {
      return trim(line.components(separatedBy: "|"))
    }

    if line.contains(",") {
      return trim(parseCSVLine(line))
    }

    return trim(splitByRepeatedWhitespace(line))
  }

  private static func hasColumnSeparator(_ line: String) -> Bool {
    line.contains("|") || line.contains("\t") || line.contains(",")
  }

  private static func trim(_ values: [String]) -> [String] {
    values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  private static func value(at index: Int?, in columns: [String]) -> String {
    guard let index, columns.indices.contains(index) else { return "" }
    return columns[index].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func unitName(
    currentUnit: String,
    explicitUnit: String?,
    number: Int,
    allowAutomaticUnits: Bool
  ) -> String {
    if let explicitUnit, !explicitUnit.isEmpty {
      return explicitUnit
    }

    if !allowAutomaticUnits || currentUnit != "Unit 1" {
      return currentUnit
    }

    return "Unit \(((number - 1) / 60) + 1)"
  }

  private static func parseCSVLine(_ line: String) -> [String] {
    var values: [String] = []
    var current = ""
    var insideQuotes = false
    var index = line.startIndex

    while index < line.endIndex {
      let character = line[index]

      if character == "\"" {
        let next = line.index(after: index)
        if insideQuotes, next < line.endIndex, line[next] == "\"" {
          current.append("\"")
          index = line.index(after: next)
        } else {
          insideQuotes.toggle()
          index = next
        }
      } else if character == ",", !insideQuotes {
        values.append(current)
        current = ""
        index = line.index(after: index)
      } else {
        current.append(character)
        index = line.index(after: index)
      }
    }

    values.append(current)
    return values
  }

  private static func splitByRepeatedWhitespace(_ line: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: "\\s{2,}") else {
      return [line]
    }

    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    let matches = regex.matches(in: line, range: range)
    guard !matches.isEmpty else { return [line] }

    var pieces: [String] = []
    var start = line.startIndex

    for match in matches {
      guard let matchRange = Range(match.range, in: line) else { continue }
      pieces.append(String(line[start..<matchRange.lowerBound]))
      start = matchRange.upperBound
    }

    pieces.append(String(line[start..<line.endIndex]))
    return pieces
  }

  private static func numberValue(from text: String) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.prefix { $0.isNumber }
    guard !digits.isEmpty else { return nil }
    return Int(digits)
  }

  private static func isHeaderRow(_ columns: [String]) -> Bool {
    let joined = columns.joined(separator: " ").lowercased()
    return joined.contains("number")
      && joined.contains("term")
      && joined.contains("pinyin")
  }
}

private struct ColumnLayout {
  let numberIndex: Int?
  let unitIndex: Int?
  let termIndex: Int
  let pinyinIndex: Int
  let partOfSpeechIndex: Int?
  let definitionIndex: Int
  let usageIndex: Int?
  let exampleChineseIndex: Int?
  let examplePinyinIndex: Int?
  let exampleEnglishIndex: Int?

  init?(headers: [String]) {
    guard let termIndex = headers.firstIndex(where: Self.isTermHeader),
          let pinyinIndex = headers.firstIndex(where: Self.isPinyinHeader),
          let definitionIndex = headers.firstIndex(where: Self.isDefinitionHeader) else {
      return nil
    }

    self.numberIndex = headers.firstIndex(where: Self.isNumberHeader)
    self.unitIndex = headers.firstIndex(where: Self.isUnitHeader)
    self.termIndex = termIndex
    self.pinyinIndex = pinyinIndex
    self.partOfSpeechIndex = headers.firstIndex(where: Self.isPartOfSpeechHeader)
    self.definitionIndex = definitionIndex
    self.usageIndex = headers.firstIndex(where: Self.isUsageHeader)
    self.exampleChineseIndex = headers.firstIndex(where: Self.isExampleChineseHeader)
    self.examplePinyinIndex = headers.firstIndex(where: Self.isExamplePinyinHeader)
    self.exampleEnglishIndex = headers.firstIndex(where: Self.isExampleEnglishHeader)
  }

  private static func normalized(_ header: String) -> String {
    header.lowercased().filter { $0.isLetter || $0.isNumber }
  }

  private static func isNumberHeader(_ header: String) -> Bool {
    let value = normalized(header)
    return value == "number"
      || value == "no"
      || value == "wordnumber"
      || (value == "word" && header.contains("#"))
  }

  private static func isUnitHeader(_ header: String) -> Bool {
    let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized(header) == "unit" || trimmed.hasPrefix("unit ")
  }

  private static func isTermHeader(_ header: String) -> Bool {
    let value = normalized(header)
    return value == "term"
      || value == "chinese"
      || value == "mandarin"
      || value == "characters"
      || value == "hanzi"
  }

  private static func isPinyinHeader(_ header: String) -> Bool {
    normalized(header) == "pinyin"
  }

  private static func isPartOfSpeechHeader(_ header: String) -> Bool {
    let value = normalized(header)
    return value == "partofspeech" || value == "pos" || value == "type"
  }

  private static func isDefinitionHeader(_ header: String) -> Bool {
    let value = normalized(header)
    return value == "definition"
      || value == "meaning"
      || value == "english"
      || value == "englishmeaning"
  }

  private static func isUsageHeader(_ header: String) -> Bool {
    let value = normalized(header)
    return value == "usage"
      || value == "use"
      || value == "example"
      || value == "examplesentence"
  }

  private static func isExampleChineseHeader(_ header: String) -> Bool {
    let value = normalized(header)
    return value == "examplechinese"
      || value == "examplesentencechinese"
      || value == "chineseexample"
      || value == "chinesesentence"
      || value == "sentencechinese"
      || value == "chinesephrase"
      || value == "phrasechinese"
  }

  private static func isExamplePinyinHeader(_ header: String) -> Bool {
    let value = normalized(header)
    return value == "examplepinyin"
      || value == "examplesentencepinyin"
      || value == "pinyinexample"
      || value == "pinyinsentence"
      || value == "sentencepinyin"
      || value == "pinyinphrase"
      || value == "phrasepinyin"
  }

  private static func isExampleEnglishHeader(_ header: String) -> Bool {
    let value = normalized(header)
    return value == "exampleenglish"
      || value == "examplesentenceenglish"
      || value == "englishexample"
      || value == "englishsentence"
      || value == "sentencetranslation"
      || value == "englishtranslation"
      || value == "englishphrase"
      || value == "phraseenglish"
  }
}
