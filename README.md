# Palabra de la hora 🇲🇽

A SwiftUI + WidgetKit iPhone app that teaches one Spanish word at a time, on a schedule you pick. Each word comes with:

- a pronunciation guide (`keh-REHR`) and on-device text-to-speech (normal and slow)
- an example sentence with its translation
- a **"How to use it"** sentence pattern (e.g. `Quiero + infinitive`) and a short tip

iOS 17+, Xcode 15+ (built against the Xcode 16 project format). No third-party dependencies, no network, no audio files.

## Run it (≈2 minutes)

1. Open `PalabraDeLaHora.xcodeproj`.
2. Select the **project** (not a target) → Build Settings → set **`PALABRA_BUNDLE_ID`** to your own prefix, e.g. `com.yourname.palabra`.
   That one setting drives the app bundle ID, the widget ID (`….widget`), and the App Group (`group.…`) in both entitlements and both Info.plists.
3. For **both** targets → Signing & Capabilities → choose your Team. Automatic signing registers the App Group for you.
4. Run the `PalabraDeLaHora` scheme on the device, then long-press the Home Screen → **+** → *Palabra* and add the widget (small, medium or large). Lock Screen versions are there too (rectangular, inline, circular).

> For a nicer voice on her phone: Settings › Accessibility › Spoken Content › Voices › Spanish → download an **Enhanced** voice. The app picks the highest-quality installed voice for the accent chosen in Settings.

## What's in the box

| Feature | Where |
|---|---|
| Widget that flips to a new word exactly on the hour (or every 2/3/4/6 h, or daily) | `Widget/PalabraWidget.swift` |
| 🔊 buttons **on the widget** (interactive widget + `AudioPlaybackIntent`; no app launch) | `Shared/SpeakWordIntent.swift` |
| Tap the widget → app opens on that word and speaks it (`palabra://word/<id>?play=1`) | `App/PalabraApp.swift` (`AppRouter`) |
| Optional notification per new word, with a **🔊 Hear it** action and quiet hours | `App/NotificationScheduler.swift` |
| Hoy tab: full study card, countdown, the next 3 words | `App/ContentView.swift`, `App/WordCardView.swift` |
| Review tab: words seen so far, favorites ⭐, search, flashcard **Practice** mode | `App/ReviewView.swift` |
| Settings: cadence, accent (MX/ES/US), speech speed, notifications, reshuffle | `App/SettingsView.swift` |
| **Levels** (Novice A1 → Fluent B2–C1) and **focus** (words + phrases / everyday phrases / vocabulary) | `Shared/Word.swift` (`WordBank.deck`) |
| **"Learn the next word now"**: skip ahead without waiting. The widget, notifications and "Coming up" all shift with it | `App/ContentView.swift` (`Rotation.skipAhead`) |
| **Optional quizzes** on seen words, freshly shuffled each run. **Written**: multiple choice, fill in the blank, type it (with accent keys). **Verbal**: hands-free; it asks out loud and checks her spoken answer with speech recognition. Results let her review missed words or quiz again on just those | `App/QuizView.swift`, `App/SpeechListener.swift`, `Shared/LearningProgress.swift` |
| 284-card deck: 205 words + 79 everyday phrases and idioms, tagged by level | `Shared/words.json` (source: `tools/words_source.py`, `tools/new_words.py`) |

## How the schedule works

`WordSchedule` cuts time into slots aligned to the local clock (hourly slots start at :00, daily at midnight). Each run through the deck uses its own seeded shuffle (SplitMix64 + hand-rolled Fisher–Yates, so it stays stable across Swift versions). Every word appears once per run, and the order changes each run.

Since the word for any moment can be computed, the widget pre-builds the next 24 timeline entries. It flips on time without spending its reload budget, and the app, widget and notifications always agree. The seed and the start date live in the App Group's `UserDefaults`, and the "Seen" list is derived from them, so nothing has to be synced.

## Levels

The levels loosely follow CEFR, which is also how the Instituto Cervantes curriculum is organised:

| Level | ≈ CEFR | Cards | What's in it |
|---|---|---|---|
| Novice | A1 | 95 | greetings, core verbs, family, food, time |
| Beginner | A2 | 86 | routines, plans, feelings, shopping, asking for things |
| Intermediate | B1 | 60 | reflexive verbs, connectors (aunque, sin embargo), opinions, Mexican slang |
| Fluent | B2–C1 | 43 | false friends, idioms, subjunctive/conditional patterns |

"Everyday phrases" always includes the phrases from every level up to the one selected. Each level only has a few dozen phrases, and the easier ones are the most useful in conversation.

## Skipping ahead

`WordSchedule` adds `AppSettings.skipOffset` to the clock slot. "Next word" increments it, reloads the widget timelines and re-queues notifications. When the next hour arrives she continues from where she skipped to, so nothing repeats. Seen words are recorded in the App Group by `LearningProgress.catchUp()`, which runs from both the app and the widget, so the Review and Quiz tabs include words she skipped past.

## Building the full deck from a dictionary

The app ships with the 284 hand-written cards. To add thousands of dictionary cards, run this once on your Mac. It needs only plain Python 3:

```bash
python3 tools/import_dictionary.py            # ~5,000 cards (use --count 8000 for more)
```

| Card field | Source |
|---|---|
| which words, in what order, and the level | FrequencyWords (OpenSubtitles 2018), CC BY-SA 4.0. Conjugated forms are counted toward their dictionary word. Rank ≤600 → Novice, ≤1,500 → Beginner, ≤3,000 → Intermediate, then Fluent |
| meaning, part of speech, gender, "Key forms" (yo tengo · tú tienes · él/ella tiene, el/la + plural, adjective endings) | English Wiktionary via Wiktextract / kaikki.org, CC BY-SA |
| example sentence and translation | Tatoeba, CC BY 2.0 FR. Short sentences built from the easiest vocabulary are preferred. Ambiguous words like *como* use Wiktionary's own example for the right meaning |
| phonetic spelling (`keh-REHR`) | generated from Spanish spelling rules. It matches 279 of the 284 hand-written ones |

**Words with several meanings** (cuarto = *room* / *fourth* / *quarter*) get up to three. Each meaning has its own example, and a sentence only counts for a meaning if its English translation actually uses that meaning, so a "room" example always says "room". The meaning with the most real sentences comes first. Hand-written cards with two meanings (querer, tiempo, esperar, tarde …) are split the same way in `tools/new_words.py` (`MEANINGS`).

**Beginner-friendly examples.** For each meaning, the importer prefers sentences that use the plain form (*quitar*) or the present tense. Past tenses, commands, subjunctives and attached pronouns (*quítate*) are used only when nothing simpler exists, and even less for Novice/Beginner words. The word is highlighted in the example. When the example uses a form not in the Key forms table, the card explains it in plain English, e.g. "**quítate** = *quita* (a command to you) + *te* (yourself)" or "**quitaron** = *quitar* → the past tense for they". That form is also added to Key forms as "in the example". Hand-written cards get the same notes from `tools/curated_forms.py` (`EXAMPLE_NOTES`).

Words tagged vulgar, offensive or derogatory in Wiktionary are skipped, along with sentences that contain them. Hand-written cards always win over generated ones for the same word. The first run downloads about 1–3 GB into `tools/.cache/` (git-ignored) and takes a few minutes. After that, the filtered subset is cached. The output goes to `tools/generated.json` (commit it) and is merged into `Shared/words.json`. Attribution is in Settings › About › Credits & licenses.

## Adding words

Key forms for hand-written cards live in `tools/curated_forms.py`. These are conjugation, article/plural and adjective-ending tables, checked by hand. Any word missing there falls back to the dictionary's forms once you've imported. Add lines to `tools/new_words.py` under the right `## level` heading, then run `python3 tools/words_source.py`. It writes `tools/curated.json` and re-merges `Shared/words.json`, keeping any dictionary cards you've imported. The format is pipe-delimited: `spanish | english | part of speech | phonetic | example | translation | pattern | tip?`. Use `phrase` or `idiom` as the part of speech to make an entry an everyday-phrase card. You can also edit the JSON by hand: `tip` is optional, and `id` must be unique and URL-safe.

## Things worth knowing

- **Widget audio.** The 🔊 widget buttons use `AudioPlaybackIntent`. Its file is compiled into both targets and the app declares the `audio` background mode, so iOS can run it in the app process without opening the app. Test this on a real device: Simulator audio from widget intents is unreliable. Tapping anywhere else on the widget always opens the app and speaks.
- **Notifications** are local and pre-scheduled. iOS keeps at most 64, and the app queues up to 60, which is 2–3 days on the hourly cadence. The queue refills every time the app comes to the foreground. If she goes days without opening the app, the notifications stop, but the widget keeps rotating. A `BGAppRefreshTask` would remove that limit if you want it.
- `tools/gen_xcodeproj.py` regenerates the `.pbxproj` if you add files outside Xcode. `project.yml` is an XcodeGen alternative.

## Ideas for v2

- Spaced repetition: show "Still learning" words from Practice more often (feed them into `WordSchedule`).
- A Siri / App Shortcut ("¿Cuál es la palabra?") using the existing intent.
- Bundle recorded native-speaker audio per word, and fall back to TTS when a recording is missing.
- Themed decks, such as wedding, travel, family or food.
