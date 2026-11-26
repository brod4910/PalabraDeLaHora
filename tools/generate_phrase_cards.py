#!/usr/bin/env python3
"""
Generates everyday *phrase cards* (¿qué onda?, ni modo, me late, ¿me pasas…?): common Mexican
Spanish expressions, each with a meaning, an example, "how to use it" and an optional tip — like
the hand-written phrase cards, but enough of them that the "Everyday phrases" focus doesn't cycle.

    python3 tools/generate_phrase_cards.py --backend claude-code --levels novice     # Claude plan
    python3 tools/generate_phrase_cards.py --backend claude-code                     # all levels
    python3 tools/generate_phrase_cards.py --dry-run

For each level it asks, per situation (at home, food, texting, couple…), for --per expressions
that are common in Mexico and right for the level, avoiding ones the deck already has. Every
card is then checked like the everyday phrases: the example must contain the expression and use
vocabulary of the level (tools/generate_phrases.py Checker), and a second pass reviews it as a
native es-MX speaker. Results are cached per level and situation (tools/.cache/phrase_cards/),
written to tools/phrase_cards.json, and merged into Shared/words.json (hand-written cards win).

Afterwards, give the new cards everyday phrases and audio like any other card:
    python3 tools/generate_phrases.py --backend claude-code --levels novice
    python3 tools/generate_audio.py --levels novice --voice Paloma
"""
from __future__ import annotations

import argparse
import concurrent.futures as futures
import json
import os
import pathlib
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import import_dictionary as dict_tools  # noqa: E402
import generate_phrases as gp  # noqa: E402

ROOT = dict_tools.ROOT
CACHE = dict_tools.CACHE / "phrase_cards"
OUTPUT = dict_tools.TOOLS / "phrase_cards.json"
PROMPT_VERSION = 1

LEVEL_GUIDE = {
    "novice": "a complete beginner (CEFR A1): the most common, short (1–4 words) expressions, simple present "
              "tense, things heard every single day",
    "beginner": "a beginner (A2): very common everyday expressions, up to 5 words",
    "intermediate": "an intermediate learner (B1): common colloquial expressions and set phrases, including "
                    "Mexican ones (ahorita, ¿mande?, me late, está padre)",
    "fluent": "an advanced learner (B2–C1): idiomatic and colloquial Mexican expressions natives use often",
}

GENERATE = """Spanish variety: {variety}

List {n} different everyday expressions (not single dictionary words, unless it's an interjection
like "¡órale!") that people in Mexico really say in this situation: {situation}.
They are for {level_guide}.

Rules:
- Common in everyday Mexican speech. No Spain-only usage (vale, tío, guay, vosotros, coger),
  nothing rare, literary, vulgar or offensive.
- Not any of these, which the learner already has: {avoid}
- "spanish": the expression as written, with ¿?/¡! when it's a question or exclamation, and "…" where
  it continues (e.g. "¿Me pasas…?").
- "english": a natural meaning in a few words (not word-for-word).
- "example": one short natural sentence (3–10 words) that contains the expression exactly, and
  "example_en": its natural English translation.
- "pattern": how to use it, under 12 words, e.g. "¿Me pasas + thing? = Can you pass me…?" or
  "answering the phone".
- "tip": optional, under 15 words, only if useful (register, who says it, a common mistake). Else "".

Return JSON exactly: {{"phrases": [{{"spanish": "...", "english": "...", "example": "...", "example_en": "...",
"pattern": "...", "tip": ""}}]}}"""

REVIEW = """You are a native {variety_short} Spanish speaker and a careful Spanish teacher. Check each
everyday expression written for a learner at the given level. Approve it ("ok": true) only if ALL are true:
1. People in Mexico really say it in everyday life (not Spain-only, rare, literary, vulgar or offensive).
2. The English meaning is accurate.
3. The example is natural, uses the expression with that meaning, and its translation is accurate.
4. The pattern and the tip (if any) are correct and helpful.
5. Right for the level (a novice should get short, very common expressions).

Expressions:
{items}

Return JSON exactly: {{"verdicts": [{{"pid": "...", "ok": true, "reason": ""}}]}}"""


def same_text(s: str) -> str:
    return " ".join(dict_tools.tokens(dict_tools.strip_accents(s)))


def core(expression: str) -> str:
    """The expression without punctuation or a trailing '…': '¿Me pasas…?' → 'Me pasas'."""
    return expression.replace("…", " ").replace("...", " ").strip(" ¿?¡!.,;:")


def cache_path(level: str, situation: str) -> pathlib.Path:
    return CACHE / f"{level}-{situation}.json"


def run_one(level: str, situation: str, avoid: list[str], args, checker: gp.Checker,
            deck_words: set[str], api_key: str | None) -> tuple[list[dict], list[tuple[str, str]]]:
    prompt = GENERATE.format(variety=gp.VARIETIES[args.variety], n=args.per, situation=situation,
                             level_guide=LEVEL_GUIDE[level], avoid=", ".join(avoid[:150]) or "(none)")
    result, _ = gp.ask(args, gp.SYSTEM, prompt, max_tokens=350 * args.per + 500, api_key=api_key)
    candidates, dropped = [], []
    for ph in result.get("phrases", []):
        spanish, example = (ph.get("spanish") or "").strip(), (ph.get("example") or "").strip()
        if not spanish or not ph.get("english") or not example or not ph.get("example_en"):
            dropped.append((spanish, "incomplete")); continue
        card = {"spanish": core(spanish), "kind": "phrase", "level": level}
        reason = checker.check(card, {"es": example, "en": ph["example_en"], "form": core(spanish)}, deck_words)
        if reason:
            dropped.append((spanish, reason)); continue
        candidates.append({**ph, "pid": dict_tools.phrase_id(spanish)})

    if candidates and not args.no_review:
        items = [{"pid": c["pid"], "level": level, "expression": c["spanish"], "english": c["english"],
                  "example": c["example"], "example_en": c["example_en"], "pattern": c.get("pattern", ""),
                  "tip": c.get("tip", "")} for c in candidates]
        verdicts, _ = gp.ask(args, "Return only JSON.",
                             REVIEW.format(variety_short=args.variety, items=json.dumps(items, ensure_ascii=False, indent=1)),
                             max_tokens=60 * len(items) + 300, api_key=api_key,
                             model=args.review_model or args.model)
        ok = {v["pid"] for v in verdicts.get("verdicts", []) if v.get("ok") is True}
        reasons = {v["pid"]: v.get("reason", "") for v in verdicts.get("verdicts", [])}
        dropped += [(c["spanish"], "review: " + (reasons.get(c["pid"]) or "not approved")) for c in candidates if c["pid"] not in ok]
        candidates = [c for c in candidates if c["pid"] in ok]

    cards = []
    for c in candidates:
        card = {"spanish": c["spanish"], "english": c["english"].strip(), "partOfSpeech": "phrase",
                "phonetic": dict_tools.respell(core(c["spanish"])), "example": c["example"].strip(),
                "exampleTranslation": c["example_en"].strip(), "pattern": (c.get("pattern") or "").strip(),
                "level": level, "kind": "phrase", "source": "ai", "situation": situation}
        if (c.get("tip") or "").strip():
            card["tip"] = c["tip"].strip()
        cards.append(card)
    return cards, dropped


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--levels", nargs="+", default=["novice", "beginner", "intermediate", "fluent"],
                    choices=["novice", "beginner", "intermediate", "fluent"])
    ap.add_argument("--per", type=int, default=10, help="expressions to ask for per situation (default 10)")
    ap.add_argument("--backend", choices=["api", "claude-code"], default="api")
    ap.add_argument("--model", default="claude-sonnet-5-5")
    ap.add_argument("--review-model")
    ap.add_argument("--no-review", action="store_true")
    ap.add_argument("--variety", default="es-MX", choices=sorted(gp.VARIETIES))
    ap.add_argument("--workers", type=int)
    ap.add_argument("--redo", action="store_true", help="ignore cached results")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--yes", action="store_true")
    args = ap.parse_args()

    deck = json.loads(dict_tools.DECK.read_text(encoding="utf-8"))
    situations = [s for s in gp.SITUATIONS]
    todo = [(lv, s) for lv in args.levels for s in situations if args.redo or not cache_path(lv, s).exists()]
    print(f"{len(todo)} level × situation batches to write ({args.per} expressions each, model {args.model})"
          + (" through Claude Code — uses your Claude plan's limits." if args.backend == "claude-code" else "."))
    if args.dry_run or not todo:
        finish(deck)
        return

    api_key = None
    if args.backend == "claude-code":
        if not shutil.which("claude"):
            sys.exit("Claude Code isn't installed, or use --backend api.")
    else:
        api_key = os.environ.get("ANTHROPIC_API_KEY") or sys.exit("Set ANTHROPIC_API_KEY, or use --backend claude-code.")
    if not args.yes and input("Continue? [y/N] ").strip().lower() != "y":
        return

    checker = gp.Checker()
    deck_words = {t for c in deck for t in dict_tools.tokens(c["spanish"])}
    for c in deck:
        deck_words |= {v.lower() for v in dict_tools.form_values(c.get("forms"))}
    existing = [c["spanish"] for c in deck if c.get("kind") == "phrase"]
    CACHE.mkdir(parents=True, exist_ok=True)
    log = dict_tools.CACHE / "phrase_cards_dropped.tsv"
    kept = dropped_n = 0
    workers = args.workers or (2 if args.backend == "claude-code" else 4)
    with futures.ThreadPoolExecutor(max_workers=workers) as pool, open(log, "w", encoding="utf-8") as out:
        jobs = {pool.submit(run_one, lv, s, existing, args, checker, deck_words, api_key): (lv, s) for lv, s in todo}
        for n, job in enumerate(futures.as_completed(jobs), 1):
            lv, s = jobs[job]
            try:
                cards, dropped = job.result()
            except gp.UsageLimitReached as err:
                print(f"\n  Claude plan usage limit reached ({err}). Re-run later to continue.")
                for other in jobs:
                    other.cancel()
                break
            except futures.CancelledError:
                continue
            except Exception as err:            # noqa: BLE001 — retried next run
                print(f"\n  {lv}/{s} failed: {err}")
                continue
            cache_path(lv, s).write_text(json.dumps({"version": PROMPT_VERSION, "cards": cards}, ensure_ascii=False),
                                         encoding="utf-8")
            for es, reason in dropped:
                out.write(f"{lv}\t{s}\t{es}\t{reason}\n")
            kept += len(cards); dropped_n += len(dropped)
            print(f"\r  {n}/{len(todo)} batches · {kept} phrase cards kept · {dropped_n} dropped", end="", flush=True)
    print(f"\nDropped expressions and reasons: {log.relative_to(ROOT)}")
    finish(deck)


def finish(deck: list[dict]) -> None:
    """All cached cards → tools/phrase_cards.json (deduplicated), then merge into the deck."""
    have = {same_text(core(c["spanish"])) for c in deck if c.get("source") != "ai" or c.get("kind") != "phrase"}
    order = {"novice": 0, "beginner": 1, "intermediate": 2, "fluent": 3}
    cards, seen = [], set()
    for path in sorted(CACHE.glob("*.json"), key=lambda p: (order.get(p.stem.split("-")[0], 9), p.stem)) if CACHE.exists() else []:
        for c in json.loads(path.read_text(encoding="utf-8")).get("cards", []):
            key = same_text(core(c["spanish"]))
            if key and key not in have and key not in seen:     # the easiest level wins for repeats
                seen.add(key)
                cards.append(c)
    if cards or OUTPUT.exists():
        OUTPUT.write_text(json.dumps(cards, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        by_level: dict[str, int] = {}
        for c in cards:
            by_level[c["level"]] = by_level.get(c["level"], 0) + 1
        print(f"{len(cards):,} phrase cards → {OUTPUT.relative_to(ROOT)} ({', '.join(f'{k} {v}' for k, v in by_level.items())})")
    dict_tools.merge()


if __name__ == "__main__":
    main()
