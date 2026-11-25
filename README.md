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
| 63-word starter deck (verbs, nouns, connectors, phrases, plus a few couple-y ones) | `Shared/words.json` |

## How the schedule works

`WordSchedule` cuts time into slots aligned to the local clock (hourly slots start at :00, daily at midnight). Each run through the deck uses its own seeded shuffle (SplitMix64 + hand-rolled Fisher–Yates, so it stays stable across Swift versions). Every word appears once per run, and the order changes each run.

Since the word for any moment can be computed, the widget pre-builds the next 24 timeline entries. It flips on time without spending its reload budget, and the app, widget and notifications always agree. The seed and the start date live in the App Group's `UserDefaults`, and the "Seen" list is derived from them, so nothing has to be synced.

## Adding words

Edit `tools/words_source.py`, then run `python3 tools/words_source.py` to regenerate `Shared/words.json`. You can also edit the JSON by hand: `tip` is optional, and `id` must be unique and URL-safe.

## Things worth knowing

- **Widget audio.** The 🔊 widget buttons use `AudioPlaybackIntent`. Its file is compiled into both targets and the app declares the `audio` background mode, so iOS can run it in the app process without opening the app. Test this on a real device: Simulator audio from widget intents is unreliable. Tapping anywhere else on the widget always opens the app and speaks.
- **Notifications** are local and pre-scheduled. iOS keeps at most 64, and the app queues up to 60, which is 2–3 days on the hourly cadence. The queue refills every time the app comes to the foreground. If she goes days without opening the app, the notifications stop, but the widget keeps rotating. A `BGAppRefreshTask` would remove that limit if you want it.
- `tools/gen_xcodeproj.py` regenerates the `.pbxproj` if you add files outside Xcode. `project.yml` is an XcodeGen alternative.

## Ideas for v2

- Spaced repetition: show "Still learning" words from Practice more often (feed them into `WordSchedule`).
- A Siri / App Shortcut ("¿Cuál es la palabra?") using the existing intent.
- Bundle recorded native-speaker audio per word, and fall back to TTS when a recording is missing.
- Themed decks, such as wedding, travel, family or food.
