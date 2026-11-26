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
three styles so you can pick: CAPS for the stressed syllable, *stars* around it, or plain.

Standard library only. PALABRA_INWORLD_URL overrides the API URL (for tests).
"""
from __future__ import annotations

import argparse
import base64
import concurrent.futures as futures
import hashlib
import html
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import import_dictionary as dict_tools  # noqa: E402

ROOT = dict_tools.ROOT
DECK = dict_tools.DECK
AUDIO = dict_tools.CACHE / "audio"
API = os.environ.get("PALABRA_INWORLD_URL", "https://api.inworld.ai")
PRICE_PER_MILLION = 25.0       # inworld-tts-2 on demand; lower on paid plans
SLOW_STYLES = ("caps", "stars", "plain")
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


def slow_text(text: str, style: str, pause_ms: int) -> str:
    """'oportunidad' → 'o <break/> por <break/> tu <break/> ni <break/> DAD' (style caps)."""
    gap = f' <break time="{pause_ms}ms" /> '
    word_gap = f' <break time="{pause_ms * 2}ms" /> '
    words = []
    for w in dict_tools.tokens(text):
        syl = dict_tools.syllabify(w)
        k = stressed_index(w, syl)
        if len(syl) > 1 and style == "caps":
            syl[k] = syl[k].upper()
        elif len(syl) > 1 and style == "stars":
            syl[k] = f"*{syl[k]}*"
        words.append(gap.join(syl))
    return word_gap.join(words) or text


def key_forms(card: dict) -> list[str]:
    out = []
    for forms in [card.get("forms")] + [m.get("forms") for m in card.get("otherMeanings") or []]:
        for v in dict_tools.form_values(forms):
            if v and not v.startswith("("):
                out.append(v)
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
    ap.add_argument("--slow-style", default="caps", choices=SLOW_STYLES)
    ap.add_argument("--slow-rate", type=float, default=0.85, help="speaking rate for the slow clip (0.5–1.5)")
    ap.add_argument("--pause-ms", type=int, default=350, help="pause between syllables in the slow clip")
    ap.add_argument("--bitrate", type=int, default=48000, help="MP3 bits per second (32000 is enough for voice)")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--list-voices", action="store_true")
    ap.add_argument("--dry-run", action="store_true", help="count characters and cost, call nothing")
    ap.add_argument("--yes", action="store_true", help="don't ask before spending")
    args = ap.parse_args()
    voices = args.voice or ["Paloma"]

    key = os.environ.get("INWORLD_API_KEY", "").strip()
    if not key and not args.dry_run:
        sys.exit("Set INWORLD_API_KEY first (export INWORLD_API_KEY=...). It is never printed or saved.")
    if args.list_voices:
        list_voices(key)
        return

    deck = json.loads(DECK.read_text(encoding="utf-8"))
    cards = pick_sample(deck) if args.sample else [c for c in deck if c["level"] in args.levels]

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


def group(jobs) -> dict[str, list[tuple[dict, dict, str]]]:
    out: dict[str, list] = {}
    for voice, card, clip, cid, path in jobs:
        if path.exists():
            out.setdefault(voice, []).append((card, clip, f"{voice}/{path.name}"))
    return out


if __name__ == "__main__":
    main()
