#!/usr/bin/env python3
"""
Pre-records the deck with Inworld TTS: each word (normal + slow, syllable by syllable), each
example sentence and each everyday phrase. Clips are cached by text, so nothing is paid for twice.

    export INWORLD_API_KEY=...                        # from platform.inworld.ai (never commit it)
    python3 tools/generate_audio.py --list-voices      # Spanish voices to choose from
    python3 tools/generate_audio.py --sample           # ~40 test clips + a page to listen to them
    python3 tools/generate_audio.py --sample --voice Paloma --voice Diego   # compare voices
    python3 tools/generate_audio.py --levels novice    # the real thing (shows the cost first)

Output: tools/.cache/audio/<voice>/<hash>.mp3, tools/.cache/audio/<voice>/manifest.json
(text → file), and for --sample tools/.cache/audio/sample.html (open it in a browser).

Slow version: the word split into syllables with a short pause between them and the stressed
syllable emphasized, like the written respelling (oh · por · too · nee · DAHD). --sample makes
three styles so you can pick: a written accent on the stressed syllable (cá · sa), *stars*
around it, or plain.

Checking pronunciation (catches "sucedes" said as "sucodes"):

    python3 tools/generate_audio.py --check --voice Paloma            # transcribe every clip
    open tools/.cache/audio/check.html                                 # worst first, with audio
    python3 tools/generate_audio.py --check --redo-flagged --voice Paloma   # re-record + re-check
    python3 tools/generate_audio.py --redo "sucedes" --voice Paloma    # re-record specific texts

--check sends each clip to Inworld speech-to-text (without telling it the expected text) and
compares what it heard with what the clip should say. Clips that don't match are flagged.
Speech-to-text also mishears some correct clips (short words, names), so the page is for a quick
listen; --redo-flagged re-records the flagged ones with a different delivery and checks again.
After re-recording, run --export again.

Standard library only. PALABRA_INWORLD_URL overrides the API URL (for tests).
"""
from __future__ import annotations

import argparse
import base64
import concurrent.futures as futures
import difflib
import hashlib
import html
import json
import os
import pathlib
import sys
import shutil
import time
import unicodedata
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import import_dictionary as dict_tools  # noqa: E402

ROOT = dict_tools.ROOT
DECK = dict_tools.DECK
AUDIO = dict_tools.CACHE / "audio"
APP_AUDIO = ROOT / "App" / "Audio"          # bundled into the app by --export (mp3s are git-ignored)
TEST_PHRASE = "Hola, mi amor. ¿Cómo estás hoy?"   # Settings › Test voice
API = os.environ.get("PALABRA_INWORLD_URL", "https://api.inworld.ai")
PRICE_PER_MILLION = 25.0       # inworld-tts-2 on demand; lower on paid plans
# accent: the stressed syllable gets a written accent (cá · sa), which a Spanish voice reads as stress.
# CAPS was dropped: short capital syllables are read as English letters ("CA" → "see-ay").
SLOW_STYLES = ("accent", "stars", "plain")
ACUTE = {"a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú"}
LEVELS = ("novice", "beginner", "intermediate", "fluent")


# ─────────────────────────────────────────────────────────────── what to say

def stressed_index(word: str, syllables: list[str]) -> int:
    """Spanish stress: the accented syllable; else the second-to-last if the word ends in a
    vowel, n or s; else the last."""
    for i, s in enumerate(syllables):
        if any(ch in dict_tools.ACCENTED for ch in s):
            return i
    if len(syllables) == 1:
        return 0
    last = dict_tools.strip_accents(word.lower())[-1:]
    return len(syllables) - 2 if last in "aeiouns" else len(syllables) - 1


def with_accent(syllable: str) -> str:
    """cá, bién (already), bué (bue: the strong vowel), cuí (cui: the last weak vowel)."""
    if any(ch in dict_tools.ACCENTED for ch in syllable):
        return syllable
    vowels = [i for i, ch in enumerate(syllable) if ch in ACUTE]
    if not vowels:
        return syllable
    strong = [i for i in vowels if syllable[i] in "aeo"]
    i = strong[0] if strong else vowels[-1]
    return syllable[:i] + ACUTE[syllable[i]] + syllable[i + 1:]


def slow_text(text: str, style: str, pause_ms: int) -> str:
    """'oportunidad' → 'o <break/> por <break/> tu <break/> ni <break/> dád' (style accent)."""
    gap = f' <break time="{pause_ms}ms" /> '
    word_gap = f' <break time="{pause_ms * 2}ms" /> '
    words = []
    for w in dict_tools.tokens(text):
        syl = dict_tools.syllabify(w)
        k = stressed_index(w, syl)
        if len(syl) > 1 and style == "accent":
            syl[k] = with_accent(syl[k])
        elif len(syl) > 1 and style == "stars":
            syl[k] = f"*{syl[k]}*"
        words.append(gap.join(syl))
    return word_gap.join(words) or text


def lookup_key(text: str) -> str:
    """How the app finds a clip: lowercase, letters and digits only, single spaces.
    Must match RecordedVoice.key(_:) in Shared/RecordedVoice.swift."""
    text = unicodedata.normalize("NFC", text).lower()
    return " ".join("".join(ch if ch.isalnum() else " " for ch in text).split())


def key_forms(card: dict) -> list[str]:
    """Exactly what the app says when a key form is tapped (PatternRow.spokenText):
    "yo: quiero" → "yo quiero", "él / ella: quiere" → "él quiere", "plural: los amigos / las amigas"
    → "los amigos, las amigas"."""
    out = []
    for forms in [card.get("forms")] + [m.get("forms") for m in card.get("otherMeanings") or []]:
        for line in (forms or "").split("\n"):
            if ": " not in line:
                continue
            label, value = line.split(": ", 1)
            value = value.replace(" / ", ", ").strip()
            if not value:
                continue
            if label in ("yo", "tú", "nosotros"):
                value = f"{label} {value}"
            elif label == "él / ella":
                value = f"él {value}"
            elif label == "past (yo)":
                value = f"yo {value}"
            out.append(value)
    return out


def clips_for(card: dict, args) -> list[dict]:
    """Every clip a card needs. kind: word, slow-<style>, sentence, form."""
    spanish = card["spanish"].strip("¿?¡!")
    out = [{"kind": "word", "text": spanish, "rate": 1.0}]
    for style in (SLOW_STYLES if args.sample else (args.slow_style,)):
        out.append({"kind": f"slow-{style}", "text": slow_text(spanish, style, args.pause_ms),
                    "rate": args.slow_rate, "plain": spanish})
    sentences = [card["example"]] + [m.get("example") for m in card.get("otherMeanings") or []]
    sentences += [p["es"] for p in card.get("phrases") or []]
    if args.sample:
        sentences = sentences[:2]
    out += [{"kind": "sentence", "text": s, "rate": 1.0} for s in sentences if s]
    if not args.sample:
        out += [{"kind": "form", "text": f, "rate": 1.0} for f in key_forms(card)]
    return out


def pick_sample(deck: list[dict]) -> list[dict]:
    """A varied Novice sample: short and long words, accents, a phrase card."""
    novice = [c for c in deck if c["level"] == "novice"]
    wanted = ["casa", "oportunidad", "perro", "mañana", "también", "trabajo", "cuarto", "pequeño",
              "hablar", "música", "corazón", "llegar", "jugar", "familia", "ayer", "¿cómo estás?",
              "tortilla", "rápido", "quiero", "gracias"]
    by_word = {c["spanish"]: c for c in novice}
    picked = [by_word[w] for w in wanted if w in by_word]
    return picked + [c for c in novice if c not in picked][: max(0, 20 - len(picked))]


# ─────────────────────────────────────────────────────────────── API

def request(path: str, key: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(API + path, method="POST" if body is not None else "GET",
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Basic {key}", "Content-Type": "application/json"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as err:
            if err.code in (429, 500, 502, 503, 504) and attempt < 4:
                time.sleep(2 ** attempt * 2)
                continue
            raise RuntimeError(f"Inworld API error {err.code}: {err.read().decode('utf-8', 'replace')[:300]}")
        except (urllib.error.URLError, TimeoutError):
            if attempt < 4:
                time.sleep(2 ** attempt * 2)
                continue
            raise
    raise RuntimeError("Inworld API: too many retries")


def synthesize(clip: dict, voice: str, args, key: str) -> bytes:
    body = {
        "text": clip["text"],
        "voiceId": voice,
        "modelId": args.model,
        "language": args.language,
        "audioConfig": {"audioEncoding": "MP3", "bitRate": args.bitrate, "sampleRateHertz": 24000,
                        "speakingRate": clip["rate"]},
    }
    if args.model == "inworld-tts-2":
        body["deliveryMode"] = args.delivery
    return base64.b64decode(request("/tts/v1/voice", key, body)["audioContent"])


def clip_id(clip: dict, voice: str, args) -> str:
    raw = json.dumps([voice, args.model, args.language, args.delivery, clip["text"], clip["rate"]], ensure_ascii=False)
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:16]


# Speech-to-text only *leans* toward the language it's given and guesses from the audio; one or
# two words aren't enough (a lone "sucedes" came back as Russian or Japanese). Each clip is checked
# after this Spanish lead-in, recorded once in the same voice, which is then ignored when comparing.
CARRIER = "Repite conmigo esta palabra:"
CHECK_VERSION = "v2"


def strip_id3(mp3: bytes) -> bytes:
    """Drop a leading ID3v2 tag so two MP3s can be joined into one stream."""
    if mp3[:3] == b"ID3" and len(mp3) > 10:
        size = ((mp3[6] & 0x7F) << 21) | ((mp3[7] & 0x7F) << 14) | ((mp3[8] & 0x7F) << 7) | (mp3[9] & 0x7F)
        return mp3[10 + size:]
    return mp3


def carrier_audio(voice: str, args, key: str) -> bytes:
    path = AUDIO / voice / "_carrier.mp3"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(synthesize({"text": CARRIER, "rate": 1.0}, voice, args, key))
    return path.read_bytes()


def transcribe(audio: bytes, args, key: str) -> str:
    body = {"transcribeConfig": {"modelId": "inworld/inworld-stt-1", "audioEncoding": "MP3",
                                 "language": args.language.split("-")[0]},
            "audioData": {"content": base64.b64encode(audio).decode()}}
    data = request("/stt/v1/transcribe", key, body)
    return (data.get("transcription") or {}).get("transcript", "")


def after_carrier(heard: str) -> str:
    """The transcript minus the lead-in (matched loosely, in case it's heard slightly off)."""
    flat = lambda t: dict_tools.strip_accents(lookup_key(t)).replace(" ", "")
    lead, got = flat(CARRIER), flat(heard)
    blocks = [b for b in difflib.SequenceMatcher(None, lead, got).get_matching_blocks() if b.size >= 3]
    end = max((b.b + b.size for b in blocks if b.a + b.size >= len(lead) - 4), default=0)
    return got[end:]


def latin(text: str) -> bool:
    return all(not ch.isalpha() or ch.isascii() or "LATIN" in unicodedata.name(ch, "") for ch in text)


def heard_score(expected: str, heard: str) -> float:
    """0–1: how closely the transcript matches the text, ignoring accents, case, punctuation and
    spaces (so a slow 'su ce des' still matches 'sucedes')."""
    def flat(t: str) -> str:
        return dict_tools.strip_accents(lookup_key(t)).replace(" ", "")
    a, b = flat(expected), flat(heard)
    if not a or not b:
        return 0.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def check(voice: str, args, key: str) -> None:
    folder = AUDIO / voice
    manifest_path = folder / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"No recordings for {voice} yet.")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    results_path = folder / "check.json"
    results = json.loads(results_path.read_text(encoding="utf-8")) if results_path.exists() else {}
    if results.get("_version") != CHECK_VERSION:
        results = {"_version": CHECK_VERSION}          # earlier checks had no Spanish lead-in
    lead_in = carrier_audio(voice, args, key)
    todo = [cid for cid, m in manifest.items() if cid not in results and (folder / m["file"]).exists()
            and (not m["kind"].startswith("slow-") or m["kind"] == f"slow-{args.slow_style}")]
    print(f"{len(manifest):,} clips · {len(todo):,} to check (≈ ${len(todo) * 1.8 / 3600 * 0.15:.2f} at $0.15/hour)")

    def work(cid):
        clip = strip_id3((folder / manifest[cid]["file"]).read_bytes())
        return cid, transcribe(lead_in + clip, args, key)

    done = 0
    with futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for fut in futures.as_completed([pool.submit(work, c) for c in todo]):
            try:
                cid, heard = fut.result()
                results[cid] = heard
            except Exception as err:            # noqa: BLE001
                print("  error:", str(err)[:200])
            done += 1
            if done % 100 == 0:
                print(f"  {done:,}/{len(todo):,} checked", flush=True)
                results_path.write_text(json.dumps(results, ensure_ascii=False) + "\n", encoding="utf-8")
    results_path.write_text(json.dumps(results, ensure_ascii=False) + "\n", encoding="utf-8")

    rows, other_language = [], 0
    for cid, heard in results.items():
        m = manifest.get(cid)
        if not m:
            continue
        if not latin(heard):
            other_language += 1
            rows.append((-1.0, cid, m, heard))     # listed, but not counted as mispronounced
            continue
        score = heard_score(m["text"], after_carrier(heard))
        # Short texts get a stricter bar: one wrong letter in "sucedes" is the whole problem.
        bar = 0.9 if len(lookup_key(m["text"]).replace(" ", "")) <= 8 else 0.8
        if score < bar:
            rows.append((score, cid, m, heard))
    rows.sort(key=lambda r: (r[0] < 0, r[0]))
    (folder / "flagged.json").write_text(json.dumps([cid for sc, cid, _, _ in rows if sc >= 0]) + "\n", encoding="utf-8")
    page = AUDIO / "check.html"
    page.write_text("""<!doctype html><meta charset="utf-8"><title>Palabra · pronunciation check</title>
<style>body{font:15px -apple-system,system-ui;max-width:860px;margin:24px auto;padding:0 16px}
td{padding:6px 8px;border-bottom:1px solid #eee;vertical-align:top}.s{color:#999}audio{height:30px}</style>
<h1>Pronunciation check · """ + html.escape(voice) + f"""</h1>
<p>{len(rows) - other_language:,} of {len(results) - 1:,} clips didn't match what speech-to-text heard
(after the lead-in “{html.escape(CARRIER)}”){f"; {other_language} more were heard as another language — listen to those yourself" if other_language else ""}. Listen to the worst ones;
re-record with <code>--check --redo-flagged</code> or <code>--redo "text"</code>.</p><table>
<tr><th>score</th><th>should say</th><th>heard</th><th>kind</th><th></th></tr>
""" + "\n".join(f'<tr><td class="s">{"lang?" if sc < 0 else f"{sc:.2f}"}</td><td>{html.escape(m["text"])}</td><td>{html.escape(h or "(nothing)")}</td>'
                f'<td class="s">{m["kind"]}</td><td><audio controls preload="none" src="{html.escape(voice)}/{m["file"]}"></audio></td></tr>'
                for sc, cid, m, h in rows) + "</table>", encoding="utf-8")
    print(f"{len(rows) - other_language:,} flagged of {len(results) - 1:,}"
          + (f" ({other_language} heard as another language)" if other_language else "")
          + f" → open {page.relative_to(ROOT)}")


def redo(cids: list[str], voice: str, args, key: str) -> None:
    """Re-record clips in place (same file, so the app's index still points at them) with a
    different delivery, which gives the model another take."""
    folder = AUDIO / voice
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    results_path = folder / "check.json"
    results = json.loads(results_path.read_text(encoding="utf-8")) if results_path.exists() else {}
    retry = argparse.Namespace(**{**vars(args), "delivery": "BALANCED"})
    for cid in cids:
        m = manifest[cid]
        text = m["text"] if not m["kind"].startswith("slow-") else slow_text(m["text"], args.slow_style, args.pause_ms)
        audio = synthesize({"text": text, "rate": m["rate"]}, voice, retry, key)
        (folder / m["file"]).write_bytes(audio)
        results.pop(cid, None)
        print(f"  re-recorded: {m['text']}")
    results_path.write_text(json.dumps(results, ensure_ascii=False) + "\n", encoding="utf-8")


def list_voices(key: str) -> None:
    data = request("/voices/v1/voices", key)
    voices = data.get("voices", data if isinstance(data, list) else [])
    spanish = [v for v in voices if any(str(l).lower().startswith("es") for l in
                                        (v.get("languages") or [v.get("language", "")]))]
    for v in spanish or voices:
        langs = ",".join(map(str, v.get("languages") or [v.get("language", "")]))
        print(f"{v.get('voiceId', v.get('name', '?')):18} {langs:12} {v.get('displayName', '')}  "
              f"{(v.get('description') or '')[:80]}")
    if not spanish:
        print("\n(no voice was tagged Spanish; all voices are listed)")


# ─────────────────────────────────────────────────────────────── main

def write_sample_page(results: dict[str, list[tuple[dict, dict, str]]]) -> pathlib.Path:
    rows = []
    for voice, items in results.items():
        rows.append(f"<h2>{html.escape(voice)}</h2>")
        current = None
        for card, clip, path in items:
            if card["id"] != current:
                if current is not None:
                    rows.append("</div>")
                current = card["id"]
                rows.append(f'<div class="card"><h3>{html.escape(card["spanish"])} '
                            f'<small>{html.escape(card.get("phonetic", ""))} · {html.escape(card["english"])}</small></h3>')
            label = {"word": "normal", "sentence": "sentence"}.get(clip["kind"], clip["kind"].replace("slow-", "slow · "))
            text = clip.get("plain") if clip["kind"].startswith("slow") else clip["text"]
            sent = html.escape(clip["text"]) if clip["kind"].startswith("slow") else ""
            rows.append(f'<p><b>{label}</b> {html.escape(text or "")}<br><audio controls preload="none" '
                        f'src="{html.escape(path)}"></audio>' + (f'<br><code>{sent}</code>' if sent else "") + "</p>")
        if current is not None:
            rows.append("</div>")
    page = AUDIO / "sample.html"
    page.write_text("""<!doctype html><meta charset="utf-8"><title>Palabra · voice sample</title>
<style>body{font:15px -apple-system,system-ui;max-width:760px;margin:24px auto;padding:0 16px}
.card{border:1px solid #ddd;border-radius:12px;padding:8px 16px;margin:12px 0}h3 small{color:#777;font-weight:400}
audio{height:32px;margin-top:4px}code{color:#999;font-size:12px}</style>
<h1>Voice sample</h1><p>Compare the three slow styles and pick one with <code>--slow-style</code>.</p>
""" + "\n".join(rows), encoding="utf-8")
    return page


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sample", action="store_true", help="~20 Novice words: normal, 3 slow styles, 2 sentences")
    ap.add_argument("--levels", nargs="+", choices=LEVELS, default=["novice"])
    ap.add_argument("--voice", action="append", help="Inworld voice id (repeat to compare); default Paloma")
    ap.add_argument("--language", default="es-MX", help="BCP-47 tag (default es-MX, Mexican Spanish)")
    ap.add_argument("--model", default="inworld-tts-2")
    ap.add_argument("--delivery", default="STABLE", choices=["STABLE", "BALANCED", "CREATIVE"])
    ap.add_argument("--slow-style", default="plain", choices=SLOW_STYLES)
    ap.add_argument("--slow-rate", type=float, default=0.85, help="speaking rate for the slow clip (0.5–1.5)")
    ap.add_argument("--pause-ms", type=int, default=350, help="pause between syllables in the slow clip")
    ap.add_argument("--bitrate", type=int, default=48000, help="MP3 bits per second (32000 is enough for voice)")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--list-voices", action="store_true")
    ap.add_argument("--check", action="store_true", help="transcribe the clips and flag mispronounced ones")
    ap.add_argument("--redo-flagged", action="store_true", help="with --check: re-record the flagged clips, then check again")
    ap.add_argument("--redo", nargs="+", metavar="TEXT", help="re-record the clips for these texts (any kind)")
    ap.add_argument("--export", action="store_true",
                    help="copy this voice's recorded clips into App/Audio/ for the app (records nothing)")
    ap.add_argument("--dry-run", action="store_true", help="count characters and cost, call nothing")
    ap.add_argument("--yes", action="store_true", help="don't ask before spending")
    args = ap.parse_args()
    voices = args.voice or ["Paloma"]

    if args.export:
        export(voices[0], args)
        return

    key = os.environ.get("INWORLD_API_KEY", "").strip()
    if not key and not args.dry_run:
        sys.exit("Set INWORLD_API_KEY first (export INWORLD_API_KEY=...). It is never printed or saved.")
    if args.list_voices:
        list_voices(key)
        return
    if args.redo:
        manifest = json.loads((AUDIO / voices[0] / "manifest.json").read_text(encoding="utf-8"))
        wanted = {lookup_key(t) for t in args.redo}
        redo([cid for cid, m in manifest.items() if lookup_key(m["text"]) in wanted], voices[0], args, key)
        print("Run --export again to update the app.")
        return
    if args.check:
        check(voices[0], args, key)
        if args.redo_flagged:
            flagged = json.loads((AUDIO / voices[0] / "flagged.json").read_text(encoding="utf-8"))
            redo(flagged, voices[0], args, key)
            check(voices[0], args, key)
            print("Run --export again to update the app.")
        return

    deck = json.loads(DECK.read_text(encoding="utf-8"))
    cards = pick_sample(deck) if args.sample else [c for c in deck if c["level"] in args.levels]
    if not args.sample:
        cards = cards + [{"id": "test-voice", "spanish": TEST_PHRASE, "english": "", "example": "",
                          "level": "novice", "kind": "phrase"}]

    jobs, seen = [], set()
    for voice in voices:
        out_dir = AUDIO / voice
        for card in cards:
            for clip in clips_for(card, args):
                cid = clip_id(clip, voice, args)
                path = out_dir / f"{cid}.mp3"
                jobs.append((voice, card, clip, cid, path))
                seen.add((voice, cid))
    todo = {(v, cid): (v, card, clip, cid, path) for v, card, clip, cid, path in jobs if not path.exists()}
    chars = sum(len(clip["text"]) for _, _, clip, _, _ in todo.values())
    print(f"{len(cards):,} cards · {len(jobs):,} clips ({len(jobs) - len(todo):,} repeats or already recorded) · "
          f"{len(todo):,} to record · {chars:,} characters ≈ ${chars / 1e6 * PRICE_PER_MILLION:.2f} "
          f"at ${PRICE_PER_MILLION:.0f}/1M (less on paid plans)")
    if args.dry_run or not todo:
        if not todo and args.sample:
            print(f"Open {write_sample_page(group(jobs)).relative_to(ROOT)}")
        return
    if not args.yes and input("Record them? [y/N] ").strip().lower() != "y":
        return

    done, failed = 0, []

    def work(job):
        voice, card, clip, cid, path = job
        audio = synthesize(clip, voice, args, key)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".part")
        tmp.write_bytes(audio)
        tmp.replace(path)
        return job

    with futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for fut in futures.as_completed([pool.submit(work, j) for j in todo.values()]):
            try:
                fut.result(); done += 1
            except Exception as err:            # noqa: BLE001 — keep going, report at the end
                failed.append(str(err))
            if (done + len(failed)) % 25 == 0 or done + len(failed) == len(todo):
                print(f"  {done:,}/{len(todo):,} recorded" + (f", {len(failed)} failed" if failed else ""), flush=True)
    print()
    if failed:
        print("First error:", failed[0])

    for voice in voices:                          # text → file, for the app and later runs
        manifest_path = AUDIO / voice / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
        for v, card, clip, cid, path in jobs:
            if v == voice and path.exists():
                manifest[cid] = {"text": clip.get("plain", clip["text"]), "kind": clip["kind"],
                                 "rate": clip["rate"], "file": path.name}
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    if args.sample:
        print(f"Open {write_sample_page(group(jobs)).relative_to(ROOT)} in a browser to listen.")


def export(voice: str, args) -> None:
    """App/Audio/index.json maps lookup_key(text) → file ("slow|" + key for slow words)."""
    manifest_path = AUDIO / voice / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"No recordings for {voice} yet — run without --export first.")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    index: dict[str, str] = {}
    for cid, m in manifest.items():
        src = AUDIO / voice / m["file"]
        if not src.exists():
            continue
        if m["kind"].startswith("slow-"):
            if m["kind"] != f"slow-{args.slow_style}":
                continue
            index["slow|" + lookup_key(m["text"])] = m["file"]
        else:
            index.setdefault(lookup_key(m["text"]), m["file"])
    APP_AUDIO.mkdir(parents=True, exist_ok=True)
    keep = set(index.values())
    for old in APP_AUDIO.glob("*.mp3"):
        if old.name not in keep:
            old.unlink()
    size = 0
    for name in keep:
        dest = APP_AUDIO / name
        if not dest.exists():
            shutil.copy2(AUDIO / voice / name, dest)
        size += dest.stat().st_size
    (APP_AUDIO / "index.json").write_text(json.dumps({"voice": voice, "clips": index}, ensure_ascii=False) + "\n",
                                          encoding="utf-8")
    print(f"App/Audio: {len(keep):,} clips ({size / 1e6:.1f} MB) for {len(index):,} texts, voice {voice}. "
          "Build the app in Xcode to bundle them.")


def group(jobs) -> dict[str, list[tuple[dict, dict, str]]]:
    out: dict[str, list] = {}
    for voice, card, clip, cid, path in jobs:
        if path.exists():
            out.setdefault(voice, []).append((card, clip, f"{voice}/{path.name}"))
    return out


if __name__ == "__main__":
    main()
