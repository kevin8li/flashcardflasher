# Flashcard Generator

Native SwiftUI iOS app for generating Mandarin flashcards from a numbered glossary table.

## Run in Xcode

Open:

```text
FlashcardGenerator.xcodeproj
```

Choose the `FlashcardGenerator` scheme, select an iPhone simulator or device, then run.

## Glossary Format

The app preloads the provided 120-word Mandarin glossary on first launch. You can also tap `Provided` in the Import tab to load it into the editor and import it again.

Paste a tab, pipe, or CSV table into the Import tab:

```text
Unit 1
Number	Term	Pinyin	Definition	Usage
1	term	pin yin	definition	usage sentence
2	term	pin yin	definition	usage sentence

Unit 2
1	term	pin yin	definition	usage sentence
```

The app groups terms by `Unit` headers. Review scheduling uses three ratings: `Forgot`, `Unsure`, and `Absolutely Sure`.

The provided glossary format is also supported:

```text
Word #|Unit|Chinese|Pinyin|Part of Speech|English Meaning
1|Unit 1|阿拉伯语|Ālābóyǔ|n.|Arabic (language)
```
