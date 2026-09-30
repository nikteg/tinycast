# Typing Practice

Raycast's `Start Typing Practice`, which Raycast built with [Monkeytype](https://monkeytype.com): a
typing test in the palette (`.typingPractice`) with Monkeytype's rules, its English word list and
quotes, a results page with a chart, a history of personal bests, and a score card ⌘C copies as an
image.

## Invariants

- **`Model/` stays Foundation-only and takes every time as a parameter.** `TypingTest`,
  `TypingSample`, `TypingHistory`, `TypingLineLayout` and `TypingFieldEdit` are compiled by
  `typing-practice-test`; the session's clock is `systemUptime`, never the wall clock, so a clock
  change mid-test cannot bend a result.
- **The keys arrive through a hidden `TextField`, never a key monitor.** Its field editor keeps key
  repeat, dead keys, IME and ⌥⌫ for free; `TypingFieldEdit` turns each edit to its text back into
  keys. The text always starts with a zero-width sentinel, so a backspace on an empty word still
  deletes something and is seen. Arrows are swallowed on the field: a caret moved inside it would make
  the next key an edit mid-word. A key the test refuses is taken back out by resetting the text.
- **The screen owns the keyboard.** `hidesSearchField` is true, and the view reports its field through
  `noteEditingField`, so a bare backspace edits the word instead of leaving the screen. ⇥ and ⇧⇥ are
  claimed through `tab(at:backwards:)`; ⌘C is caught in `PaletteWindowController.onCommandShortcut`,
  since the field editor would otherwise take it as an empty copy.
- **Monkeytype's rules, not a looser version of them.** The first key starts the clock. Space on an
  empty word does nothing, so a double space never skips a word. Backspace can return to the previous
  word only while that word is wrong. A letter past a word's end is kept as an extra, up to
  `TypingTest.extraCharacterLimit`. A quote ends the moment its last word is right, or on a space after
  it; a time test ends on the clock and its last word, cut off, never counts as missed.
- **The scoring is Monkeytype's.** WPM counts the characters of fully correct words plus the space
  after each, over five; raw counts everything typed; accuracy is correct keys over all keys, where
  the space after a wrong word is a wrong key; consistency maps the spread of per-second raw speed
  onto 0–100 with Monkeytype's `kogasa` curve.
- **Leaving ends the test.** Hiding the palette mid-test puts the same words back, unstarted; leaving
  the screen drops the test and its result, so the next visit starts clean.
- **The word list and quotes are generated.** `Resources/TypingWords.generated.json` and
  `TypingQuotes.generated.json` come from `node Scripts/gen-typing-data.js`, pinned to a Monkeytype
  commit, and are never hand-edited. Monkeytype is GPL-3.0, which the AGPL may carry; the attribution
  is in `NOTICE.md`. The quotes are two megabytes, so they are decoded off the main actor on the first
  test and kept in memory after.

## Tests

| Setting | Options |
| --- | --- |
| time | 15, 30, 60 or 120 seconds of random words from Monkeytype's 200 most common English words |
| quote | all, short (≤100 characters), medium (≤300), long (≤600) or thicc — Monkeytype's groups |

The bar above the text picks one, as does the ⌘K menu. The choice is remembered in
`typing-practice.json`, alongside the history. A time test keeps `wordsAhead` words beyond the caret,
never repeats a word twice running, and a new quote is never the one just typed.

## Screen

The text is shown three lines at a time in a monospaced face, so wrapping and the caret are column
arithmetic (`TypingLineLayout`): the caret stays on the middle line once the first has been typed past.
Typed letters are full ink, wrong ones red in the letter that was wanted, extras a fainter red, and a
word passed with a mistake is underlined. The caret blinks until the first key, then glides. While a
test runs, the settings, hints and footer fade and the countdown — or the words typed of a quote —
shows with the live WPM.

| Key | Does |
| --- | --- |
| ⇥ | a new test, at any point |
| ⇧⇥ | the same words or quote again |
| ↵ | a new test, once the last one has ended; mid-test it does nothing |
| ⌘C | copy the score card, on the results |
| esc | leave, as on any screen |

## Results

WPM and accuracy, a chart of WPM (caret colour) and raw speed (faint) per second with a red dot on
each second that had a mistake, then test type, raw, characters (correct / incorrect / extra /
missed), consistency and time. Below them: a new personal best, or the standing one, the average of
the last ten tests of the same kind, and how many have been taken. A quote shows its source.

`TypingHistory` keeps up to `limit` records — the numbers only, never the chart — and a personal best
is only ever compared within one test kind (`TypingTestConfig.title`). Clear History, in ⌘K, asks
first.

The score card is `TypingScoreCard`: the same stats on an opaque `scoreCardSurface`, rendered at twice
its points in the current appearance and put on the pasteboard as an image.

## Layout

| File | Holds |
| --- | --- |
| `Model/TypingTestConfig.swift` | the test kinds and quote-length groups |
| `Model/TypingCorpus.swift` | the words and quotes, and the random picks from them |
| `Model/TypingTest.swift` | the test's state machine and its scoring |
| `Model/TypingResult.swift` | per-second samples, consistency, the result and its history record |
| `Model/TypingHistory.swift` | past records, personal bests and averages |
| `Model/TypingLineLayout.swift` | wrapping on a monospaced grid, and which lines are shown |
| `Model/TypingFieldEdit.swift` | the hidden field's edits, turned into keys |
| `Service/TypingHistoryStore.swift` | `typing-practice.json`, and loading the bundled data |
| `UI/TypingPracticeSession.swift` | the test on screen, its clock, and the field's text |
| `UI/TypingPracticeCoordinator.swift` | showing the screen, copying the card, clearing history |
| `UI/TypingPracticeScreen.swift` | the `PaletteScreen`: keys, ↵ and ⌘K |
| `UI/TypingPracticeView.swift` | the hidden field, the settings bar and the text |
| `UI/TypingResultView.swift` | the results, the chart and the score card |
