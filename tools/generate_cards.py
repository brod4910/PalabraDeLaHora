#!/usr/bin/env python3
"""
Writes the learner content of every word card with Claude, replacing the hand-written cards:
everyday Mexican meaning(s) — correcting the dictionary where it's wrong (mi = "my", not the
Greek letter) — a simple example for each, "How to use it", an optional tip, and key forms for
words the dictionary has none for.

    python3 tools/generate_cards.py --backend claude-code --levels novice     # Claude plan
    python3 tools/generate_cards.py --backend claude-code                     # every level
    python3 tools/generate_cards.py --dry-run

Words: every dictionary card (tools/generated.json) plus tools/extra_words.txt (little words,
reflexive verbs and multi-word words the import doesn't make). Each card is checked like the
everyday phrases: every example must contain a form of the word with vocabulary of its level
(generate_phrases.Checker), grammar notes come from the importer's analyzer, and a review pass
approves it as a native es-MX teacher. Rejected cards keep the dictionary's version.

Results are cached per word (tools/.cache/cards/), written to tools/cards.json and merged into
Shared/words.json by import_dictionary.merge(); a word with a generated card no longer uses its
hand-written card. A card is rewritten only when its word, level or dictionary meanings change.
"""
from __future__ import annotations

import argparse
import concurrent.futures as futures
import hashlib
import json
import os
import pathlib
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import import_dictionary as dict_tools  # noqa: E402
import generate_phrases as gp  # noqa: E402

ROOT = dict_tools.ROOT
CACHE = dict_tools.CACHE / "cards"
OUTPUT = dict_tools.TOOLS / "cards.json"
EXTRA = dict_tools.TOOLS / "extra_words.txt"
PROMPT_VERSION = 1
LEVELS = ("novice", "beginner", "intermediate", "fluent")
POS = ("noun (m.)", "noun (f.)", "noun (m./f.)", "verb", "adjective", "adverb", "pronoun", "preposition",
       "conjunction", "article", "determiner", "number", "interjection", "phrase")

GENERATE = """Spanish variety: {variety}

For EACH word below, write a learner card for an English-speaking adult learning Mexican Spanish.
You get the dictionary's meanings, which can be wrong, rare or describe the word instead of
translating it; use them only as a hint.

- "meanings": 1 to 3 everyday meanings in Mexico, the most common first. Correct the dictionary when
  it's wrong (mi = "my", not "mu"). Leave out rare, regional, literary, slang or vulgar senses.
  Each meaning: "english" (1–5 words), "part_of_speech" (one of: {pos}), "example" (one natural
  everyday sentence of 4–9 words that uses the word with that meaning) and "example_en" (a natural
  translation in the same tense).
- Examples at the word's level: novice/beginner = present tense, the infinitive or a simple tú command,
  only very common words; intermediate/fluent = any tense, still everyday and natural.
- No real people's names, brands, or sensitive or explicit content. Use tú.
- "pattern": "How to use it", under 14 words, parts separated by " · ", e.g.
  "Quiero + noun · Quiero + infinitive" or "ser de + place = to be from …".
- "tip": optional, under 18 words: Mexican usage, a false friend or a common mistake. Otherwise "".
- "forms": when "needs_forms" is true, OR when the dictionary's key forms are for a different part of
  speech than your first meaning (mi as "my" vs the noun "mi"), key forms one per line as "label: value":
  verbs "yo: …", "tú: …", "él / ella: …", "nosotros: …", "past (yo): …" (reflexive: "yo: me caso");
  nouns "singular: el …", "plural: los …"; adjectives and determiners "masculine: …", "feminine: …",
  "plural: …" (or "singular: …", "plural: …" when there's no gender). Otherwise "".

Words:
{words}

Return JSON exactly:
{{"cards": [{{"id": "...", "meanings": [{{"english": "...", "part_of_speech": "...", "example": "...",
"example_en": "..."}}], "pattern": "...", "tip": "", "forms": ""}}]}}"""

REVIEW = """You are a native {variety_short} Spanish speaker and a careful Spanish teacher. Check each word card
written for an adult learner at the given level. Approve it ("ok": true) only if ALL are true:
1. The meanings are the word's real everyday meanings in Mexico, most common first, accurately translated.
2. Each example is natural, uses the word with that meaning, fits the level, and its translation is accurate.
3. "How to use it", the tip and the key forms (if any) are correct.
Otherwise "ok": false with a short reason.

Cards:
{items}

Return JSON exactly: {{"verdicts": [{{"id": "...", "ok": true, "reason": ""}}]}}"""


def read_extra() -> list[dict]:
    out = []
    for line in EXTRA.read_text(encoding="utf-8").splitlines() if EXTRA.exists() else []:
        if not line.strip() or line.startswith("#") or "|" not in line:
            continue
        word, level = (x.strip() for x in line.split("|", 1))
        out.append({"id": dict_tools.slug(word), "spanish": word, "english": "", "partOfSpeech": "",
                    "level": level, "kind": "word", "extra": True})
    return out


def signature(card: dict) -> str:
    meanings = [card.get("english", "")] + [m["english"] for m in card.get("otherMeanings") or []]
    raw = json.dumps([PROMPT_VERSION, card["spanish"], card["level"], meanings], ensure_ascii=False)
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]


def cache_path(card: dict) -> pathlib.Path:
    return CACHE / f"{dict_tools.slug(card['spanish']) or card['id']}.json"


def cached(card: dict) -> dict | None:
    path = cache_path(card)
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    return data if data.get("signature") == signature(card) else None


def describe(card: dict) -> dict:
    d = {"id": card["id"], "word": card["spanish"], "level": card["level"],
         "needs_forms": not card.get("forms")}
    if card.get("english"):
        d["dictionary_meanings"] = [card["english"]] + [m["english"] for m in card.get("otherMeanings") or []]
    if card.get("forms"):
        d["key_forms"] = card["forms"].replace("\n", "; ")
        d["key_forms_part_of_speech"] = card.get("partOfSpeech", "")
    return d


def process(batch: list[dict], args, checker: gp.Checker, deck_words: set[str], api_key: str | None):
    prompt = GENERATE.format(variety=gp.VARIETIES[args.variety], pos=", ".join(POS),
                             words=json.dumps([describe(c) for c in batch], ensure_ascii=False, indent=1))
    result, _ = gp.ask(args, gp.SYSTEM, prompt, max_tokens=600 * len(batch) + 500, api_key=api_key)
    by_id = {c["id"]: c for c in batch}
    candidates, rejected = {}, {}
    for w in result.get("cards", []):
        card = by_id.get(w.get("id"))
        if not card:
            continue
        written_forms = (w.get("forms") or "").strip() or None
        forms = written_forms or card.get("forms")
        probe = {**card, "forms": forms, "kind": "phrase" if " " in card["spanish"] else card.get("kind", "word")}
        meanings = []
        for i, m in enumerate(w.get("meanings") or []):
            if not (m.get("english") and m.get("example") and m.get("example_en")):
                continue
            ph = {"es": m["example"].strip(), "en": m["example_en"].strip(), "form": ""}
            reason = checker.check(probe, ph, deck_words)
            if reason:
                if i == 0:
                    rejected[card["id"]] = f"main example: {reason}"
                    break
                continue                        # drop a side meaning whose example doesn't check out
            pos = m.get("part_of_speech") if m.get("part_of_speech") in POS else None
            meaning = {"english": m["english"].strip(), "partOfSpeech": pos, "example": ph["es"],
                       "exampleTranslation": ph["en"]}
            if ph.get("form"):
                meaning["exampleWord"] = ph["form"]
                if (note := checker.note_for(probe, ph)):
                    meaning["exampleNote"] = note
            meanings.append(meaning)
        if card["id"] in rejected:
            continue
        if not meanings:
            rejected[card["id"]] = "no usable meaning"
            continue
        candidates[card["id"]] = {"meanings": meanings[:3], "pattern": (w.get("pattern") or "").strip(),
                                  "tip": (w.get("tip") or "").strip(),
                                  "forms": written_forms}

    if candidates and not args.no_review:
        items = [{"id": cid, "word": by_id[cid]["spanish"], "level": by_id[cid]["level"],
                  "meanings": [{k: m[k] for k in ("english", "example", "exampleTranslation")} for m in c["meanings"]],
                  "how_to_use_it": c["pattern"], "tip": c["tip"], "key_forms": c["forms"] or ""}
                 for cid, c in candidates.items()]
        verdicts, _ = gp.ask(args, "Return only JSON.",
                             REVIEW.format(variety_short=args.variety, items=json.dumps(items, ensure_ascii=False, indent=1)),
                             max_tokens=80 * len(items) + 300, api_key=api_key, model=args.review_model or args.model)
        ok = {v["id"] for v in verdicts.get("verdicts", []) if v.get("ok") is True}
        reasons = {v["id"]: v.get("reason", "") for v in verdicts.get("verdicts", [])}
        for cid in list(candidates):
            if cid not in ok:
                rejected[cid] = "review: " + (reasons.get(cid) or "not approved")
                del candidates[cid]
    return candidates, rejected


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--levels", nargs="+", default=list(LEVELS), choices=LEVELS)
    ap.add_argument("--backend", choices=["api", "claude-code"], default="api")
    ap.add_argument("--model", default="claude-sonnet-5-5")
    ap.add_argument("--review-model")
    ap.add_argument("--no-review", action="store_true")
    ap.add_argument("--variety", default="es-MX", choices=sorted(gp.VARIETIES))
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--workers", type=int)
    ap.add_argument("--limit", type=int, help="at most this many words this run")
    ap.add_argument("--redo", action="store_true", help="rewrite cards even if cached (also retries rejected ones)")
    ap.add_argument("--retry-rejected", action="store_true", help="try the rejected cards again")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--yes", action="store_true")
    args = ap.parse_args()

    dictionary = json.loads(dict_tools.GENERATED.read_text(encoding="utf-8")) if dict_tools.GENERATED.exists() else []
    have = {c["spanish"].lower() for c in dictionary}
    words = dictionary + [e for e in read_extra() if e["spanish"].lower() not in have]
    order = {lv: i for i, lv in enumerate(LEVELS)}
    words = [w for w in words if w["level"] in args.levels]
    words.sort(key=lambda w: order[w["level"]])

    def needs(w):
        c = cached(w)
        return args.redo or c is None or (args.retry_rejected and c.get("rejected"))
    todo = [w for w in words if needs(w)]
    if args.limit:
        todo = todo[: args.limit]
    print(f"{len(words):,} words in {', '.join(args.levels)} · {len(todo):,} cards to write (model {args.model})"
          + (" through Claude Code — uses your Claude plan's limits." if args.backend == "claude-code" else "."))
    if args.dry_run or not todo:
        finish()
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
    deck = json.loads(dict_tools.DECK.read_text(encoding="utf-8"))
    deck_words = {t for c in deck for t in dict_tools.tokens(c["spanish"])}
    for c in deck:
        deck_words |= {v.lower() for v in dict_tools.form_values(c.get("forms"))}
    CACHE.mkdir(parents=True, exist_ok=True)
    log = dict_tools.CACHE / "cards_rejected.tsv"
    batches = [todo[i:i + args.batch] for i in range(0, len(todo), args.batch)]
    kept = rejected_n = 0
    workers = args.workers or (2 if args.backend == "claude-code" else 4)
    with futures.ThreadPoolExecutor(max_workers=workers) as pool, open(log, "w", encoding="utf-8") as out:
        jobs = {pool.submit(process, b, args, checker, deck_words, api_key): b for b in batches}
        for n, job in enumerate(futures.as_completed(jobs), 1):
            batch = jobs[job]
            try:
                cards, rejected = job.result()
            except gp.UsageLimitReached as err:
                print(f"\n  Claude plan usage limit reached ({err}). Re-run later to continue.")
                for other in jobs:
                    other.cancel()
                break
            except futures.CancelledError:
                continue
            except Exception as err:            # noqa: BLE001 — retried next run
                print(f"\n  batch failed ({', '.join(c['spanish'] for c in batch)}): {err}")
                continue
            for w in batch:
                data = {"signature": signature(w), "spanish": w["spanish"], "level": w["level"],
                        "extra": bool(w.get("extra"))}
                if w["id"] in cards:
                    data["card"] = cards[w["id"]]; kept += 1
                else:
                    data["rejected"] = rejected.get(w["id"], "not returned"); rejected_n += 1
                    out.write(f"{w['spanish']}\t{w['level']}\t{data['rejected']}\n")
                cache_path(w).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            print(f"\r  {n}/{len(batches)} batches · {kept:,} cards written · {rejected_n:,} rejected", end="", flush=True)
    print(f"\nRejected cards and reasons: {log.relative_to(ROOT)} (they keep the dictionary's version; --retry-rejected)")
    finish()


def finish() -> None:
    """Cached cards → tools/cards.json (keyed by word), then merge into the deck."""
    cards = {}
    for path in sorted(CACHE.glob("*.json")) if CACHE.exists() else []:
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("card"):
            cards[data["spanish"].lower()] = {**data["card"], "level": data["level"], "extra": data.get("extra", False),
                                              "spanish": data["spanish"]}
    if cards or OUTPUT.exists():
        OUTPUT.write_text(json.dumps(cards, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"{len(cards):,} written cards → {OUTPUT.relative_to(ROOT)}")
    dict_tools.merge()


if __name__ == "__main__":
    main()
