#!/usr/bin/env python3
"""
Writes "Everyday phrases" for every card with Claude (Anthropic API), checks them, and merges them
into Shared/words.json. Runs on your Mac; standard library only.

    export ANTHROPIC_API_KEY=sk-ant-...
    python3 tools/generate_phrases.py --dry-run              # how many words, estimated cost
    python3 tools/generate_phrases.py --levels novice        # start with the Novice words
    python3 tools/generate_phrases.py                        # everything not done yet

What it does, per batch of words:
  1. Asks Claude for N short, natural, everyday spoken phrases per word, each with a situation
     (home, restaurant, texting…), an English translation and the exact form used.
  2. Checks every phrase locally — dropped if any check fails:
       • the word (or one of its forms) is really in the phrase
       • every Spanish word exists (in the 50k-word frequency list or the deck) — catches
         invented words and typos
       • the vocabulary fits the card's level (a Novice phrase uses common words only)
       • short (2–12 words) and not a duplicate
  3. A second Claude pass reviews grammar, naturalness, translation and meaning; anything it
     doesn't approve is dropped.
  4. Beginner notes ("**quitaste** = *quitar* → past tense for you") are computed by the same
     analyzer the importer uses when Wiktionary data is cached, otherwise taken from the model.

Two ways to run it:
  --backend api          (default) Anthropic API with ANTHROPIC_API_KEY. Claude Max plans include
                         monthly API credits for this — link a Console organization in claude.ai
                         Settings › Billing, then create a key in that organization.
  --backend claude-code  Through Claude Code on this Mac (`claude -p`), signed in with your Claude
                         plan. Uses your plan's usage limits instead of API credits; slower, and a
                         big run may hit a session limit — just re-run later, it continues.

Results are cached per word (tools/.cache/phrases/), so re-runs only pay for new words.
Outputs:
  tools/phrases.json          → committed; merged into Shared/words.json by import_dictionary.py
  tools/phrases_review.md     → Novice phrases to skim
  tools/phrases_rejected.txt  → add a phrase id (one per line) to drop it on the next merge
"""
from __future__ import annotations

import argparse
import concurrent.futures as futures
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import import_dictionary as dict_tools  # noqa: E402

ROOT = dict_tools.ROOT
CACHE = dict_tools.CACHE / "phrases"
OUTPUT = dict_tools.TOOLS / "phrases.json"
REVIEW = dict_tools.TOOLS / "phrases_review.md"
REJECTED = dict_tools.TOOLS / "phrases_rejected.txt"

API_URL = os.environ.get("PALABRA_API_URL", "https://api.anthropic.com/v1/messages")
API_VERSION = "2023-06-01"
PROMPT_VERSION = 2

# USD per million tokens (input, output) — platform.claude.com/docs/en/about-claude/pricing
PRICES = {
    "claude-sonnet-5-5": (2.00, 10.00),
    "claude-haiku-5-5": (0.10, 0.50),
    "claude-opus-5-5": (4.00, 20.00),
}

SITUATIONS = ["home", "food", "shopping", "work", "travel", "texting", "family", "friends",
              "couple", "feelings", "health", "plans", "weather", "school", "everyday"]

# Highest frequency rank a word in the phrase may have (besides the card's own word).
LEVEL_VOCAB = {"novice": 3000, "beginner": 6000, "intermediate": 15000, "fluent": None}

VARIETIES = {
    "es-MX": "Mexican Spanish (use tú; ustedes for plural 'you'; Mexican everyday vocabulary like carro, celular, platicar)",
    "es-ES": "Spain Spanish (use tú and vosotros; Spain vocabulary like coche, móvil)",
    "es-US": "neutral Latin American Spanish as spoken in the US (use tú; ustedes for plural 'you')",
}

SYSTEM = """You write everyday spoken Spanish phrases for an English-speaking adult who is a complete \
beginner learning Spanish to talk with her partner and family. Phrases must be things people \
really say in daily life — short, warm, natural, never textbook-stiff. Return only JSON."""

GENERATE = """Spanish variety: {variety}

For EACH word below, write {n} different everyday phrases that use the word with the given meaning.

Rules:
- 3 to 9 words each. Things people actually say out loud or text.
- Use the word itself in the phrase (any form of it is fine).
- Meanings: use meaning 0 (the main, most common one) for most phrases. Use another listed meaning for at
  most ONE phrase, and only if it is common in everyday speech. Set "meaning" to the one you used.
  Don't use the word inside a fixed expression that hides its meaning (e.g. "qué tal" for tal, "por supuesto" for supuesto).
- Spread phrases across different situations, chosen from: {situations}.
- Level "novice" or "beginner": mostly present tense, the infinitive, and simple tú commands; at most one past-tense phrase; only very common words.
- Level "intermediate"/"fluent": any tense, still natural and common.
- Vary the form of the word across phrases when it naturally has forms (yo / tú / nosotros, a command…).
- Sound like a native speaker of this variety. No Spain-only usage (vosotros, vuestro, vale, venga, coger),
  no literary or archaic words (mas = but, he aquí), and no word-for-word calques of English.
- Prefer what a native would actually say, e.g. "¿Ya comiste?" not "¿Ya estás comido?"; "poner la mesa"; "una llamada".
- No real people's names, brands, or sensitive or explicit content.
- "en": a natural English translation (not word-for-word).
- "form": the exact word form as it appears in the phrase (copy it, including accents and attached pronouns).
- "note": if "form" is not the dictionary form, a beginner explanation under 20 words in this style:
  "**quitaste** = *quitar* → past tense for **you** (tú)". Otherwise "".

Words:
{words}

Return JSON exactly in this shape:
{{"words": [{{"id": "...", "phrases": [{{"es": "...", "en": "...", "situation": "...", "form": "...", "note": "...", "meaning": 0}}]}}]}}"""

REVIEW_PROMPT = """You are a native {variety_short} Spanish speaker and a careful Spanish teacher. Check each phrase written for a \
beginner. Approve it ("ok": true) only if ALL are true:
1. Grammatical and natural — something a native speaker would really say.
2. The English translation is accurate.
3. It uses the target word with the stated meaning.
4. The note (if any) is correct.
5. Suitable for an adult beginner (no errors, nothing awkward or inappropriate).

Phrases:
{items}

Return JSON exactly: {{"verdicts": [{{"pid": "...", "ok": true, "reason": ""}}]}}"""


# ─────────────────────────────────────────────────────────────── API

def call_claude(model: str, system: str, prompt: str, max_tokens: int, api_key: str) -> tuple[dict, dict]:
    body = json.dumps({
        "model": model,
        "max_tokens": max_tokens,
        "system": system,
        "messages": [{"role": "user", "content": prompt}],
    }).encode("utf-8")
    req = urllib.request.Request(API_URL, data=body, method="POST", headers={
        "x-api-key": api_key,
        "anthropic-version": API_VERSION,
        "content-type": "application/json",
    })
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                data = json.loads(r.read())
            text = "".join(c.get("text", "") for c in data.get("content", []) if c.get("type") == "text")
            return parse_json(text), data.get("usage", {})
        except urllib.error.HTTPError as err:
            if err.code in (429, 500, 502, 503, 529) and attempt < 4:
                time.sleep(2 ** attempt * 3)
                continue
            raise RuntimeError(f"Anthropic API error {err.code}: {err.read().decode('utf-8', 'replace')[:300]}")
        except (urllib.error.URLError, TimeoutError):
            if attempt < 4:
                time.sleep(2 ** attempt * 3)
                continue
            raise
    raise RuntimeError("Anthropic API: too many retries")


class UsageLimitReached(RuntimeError):
    """Claude Code reported the plan's usage limit — stop and resume later."""


def call_claude_code(model: str, system: str, prompt: str) -> tuple[dict, dict]:
    """Same request through Claude Code's print mode, signed in with your Claude plan."""
    env = {k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"}   # else it bills the API key
    cmd = ["claude", "-p", "--output-format", "json", "--model", model, "--max-turns", "1"]
    full_prompt = f"{system}\n\n{prompt}\n\nReply with the JSON only. Do not use any tools."
    for attempt in range(3):
        proc = subprocess.run(cmd, input=full_prompt, capture_output=True, text=True, env=env, timeout=600)
        out = proc.stdout.strip()
        try:
            envelope = json.loads(out) if out else {}
        except json.JSONDecodeError:
            envelope = {"is_error": True, "result": out}
        text = envelope.get("result", "") if isinstance(envelope, dict) else ""
        if proc.returncode == 0 and not envelope.get("is_error"):
            return parse_json(text), envelope.get("usage", {})
        message = (text or proc.stderr or "").strip()
        if re.search(r"usage limit|hit your limit|limit reached|resets? (at|in)", message, re.IGNORECASE):
            raise UsageLimitReached(message[:200])
        if attempt < 2:
            time.sleep(10 * (attempt + 1))
            continue
        raise RuntimeError(f"claude -p failed: {message[:300]}")
    raise RuntimeError("claude -p: too many retries")


def ask(args, system: str, prompt: str, max_tokens: int, api_key: str | None, model: str | None = None) -> tuple[dict, dict]:
    model = model or args.model
    if args.backend == "claude-code":
        return call_claude_code(model, system, prompt)
    return call_claude(model, system, prompt, max_tokens, api_key)


def parse_json(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    start, end = text.find("{"), text.rfind("}")
    return json.loads(text[start:end + 1])


# ─────────────────────────────────────────────────────────────── local checks

class Checker:
    def __init__(self) -> None:
        freq_path = dict_tools.CACHE / "es_50k.txt"
        if not freq_path.exists():
            dict_tools.download(dict_tools.FREQ_URL, freq_path)
        self.rank = {w: i + 1 for i, (w, _) in enumerate(dict_tools.load_frequency(freq_path))}
        subset = dict_tools.CACHE / "kaikki-es-subset.jsonl"
        self.entries = dict_tools.load_entries(subset) if subset.exists() else {}

    def known(self, token: str, deck_words: set[str]) -> bool:
        t = token.lower()
        if t in self.rank or t in deck_words:
            return True
        for clitic in dict_tools.CLITIC_ORDER:          # dámelo, quítate
            if t.endswith(clitic) and len(t) > len(clitic) + 1:
                base = dict_tools.strip_accents(t[: -len(clitic)])
                if base in self.rank or self.known_rest(base, deck_words):
                    return True
        return False

    def known_rest(self, base: str, deck_words: set[str]) -> bool:
        for clitic in dict_tools.CLITIC_ORDER:
            if base.endswith(clitic) and dict_tools.strip_accents(base[: -len(clitic)]) in self.rank:
                return True
        return base in deck_words

    def word_forms(self, card: dict) -> set[str]:
        forms = {card["spanish"].lower()}
        values = list(dict_tools.form_values(card.get("forms")))
        for m in card.get("otherMeanings") or []:
            values += dict_tools.form_values(m.get("forms"))
        articles = {"el", "la", "los", "las", "un", "una", "me", "te", "se", "nos", "a", "mí", "ti", "le"}
        for v in values:
            forms.add(v.lower())
            # "la hija" → "hija", "me acuerdo" → "acuerdo" (the article/pronoun isn't the word itself)
            forms |= {t for t in dict_tools.tokens(v) if t not in articles}
        for e in self.entries.get(card["spanish"].lower(), []):
            forms |= {f.get("form", "").lower() for f in e.get("forms", []) or [] if f.get("form")}
        return {f for f in forms if f}

    def is_form_of(self, token: str, lemma: str, forms: set[str]) -> bool:
        f = token.lower()
        if f in forms:
            return True
        if lemma in dict_tools.CLITIC_MEANING:
            # Pronoun cards (lo, los, te…): attached to a verb counts — cómelos, dímelo.
            return f.endswith(lemma) and len(f) > len(lemma) + 1
        stem = dict_tools.strip_accents(re.sub(r"(ar|er|ir)(se)?$", "", lemma))[:4]
        if len(stem) >= 3 and dict_tools.strip_accents(f).startswith(stem):
            return True
        return any(f.endswith(c) and dict_tools.strip_accents(f[: -len(c)]) in forms for c in dict_tools.CLITIC_ORDER)

    def check(self, card: dict, ph: dict, deck_words: set[str]) -> str | None:
        """None if fine, else the reason it was dropped."""
        es, en, form = ph.get("es", "").strip(), ph.get("en", "").strip(), (ph.get("form") or "").strip()
        toks = dict_tools.tokens(es)
        if not es or not en:
            return "empty"
        if not 2 <= len(toks) <= 12:
            return "length"
        lemma = card["spanish"].lower()
        forms = self.word_forms(card)
        if " " in lemma or card.get("kind") == "phrase":
            core = [t for t in dict_tools.tokens(lemma) if len(t) > 2] or dict_tools.tokens(lemma)
            if not all(c in toks or any(t.startswith(c[:4]) for t in toks) for c in core):
                return "target phrase missing"
        else:
            # The model sometimes reports the wrong word as "form" (e.g. "Ahorramos" for dinero in
            # "Ahorramos dinero"). If its form doesn't check out, look for the real one in the phrase.
            if not (form and dict_tools.find_in_sentence(es, form) and self.is_form_of(form, lemma, forms)):
                found = next((t for t in toks if self.is_form_of(t, lemma, forms)), None)
                if not found:
                    return (f"'{form}' is not a form of {lemma}" if form and dict_tools.find_in_sentence(es, form)
                            else "form not in phrase")
                ph["form"] = dict_tools.find_in_sentence(es, found) or found
        unknown = [t for t in toks if not self.known(t, deck_words)]
        if unknown:
            return "unknown words: " + ", ".join(unknown)
        limit = LEVEL_VOCAB.get(card.get("level", "fluent"))
        if limit:
            own = {t for t in toks if t in forms or dict_tools.strip_accents(t).startswith(lemma[:4])}
            hard = [t for t in toks if t not in own and len(t) > 3 and self.rank.get(t, 10**9) > limit]
            if len(hard) > 1:
                return "too advanced: " + ", ".join(hard)
        return None

    def note_for(self, card: dict, ph: dict) -> str | None:
        """Prefer the importer's analyzer (deterministic) over the model's note."""
        lemma = card["spanish"].lower()
        for e in self.entries.get(lemma, []):
            if e.get("pos") in dict_tools.POS_LABELS and ph.get("form"):
                if (a := dict_tools.analyze(ph["form"], lemma, e)):
                    return dict_tools.explain(ph["form"], lemma, a)
        note = (ph.get("note") or "").strip()
        return note or None


# ─────────────────────────────────────────────────────────────── generation

def describe_card(card: dict, n: int) -> dict:
    meanings = [card["english"]] + [m["english"] for m in card.get("otherMeanings") or []]
    d = {"id": card["id"], "word": card["spanish"], "level": card["level"],
         "part_of_speech": card["partOfSpeech"], "meanings": meanings}
    if card.get("forms"):
        d["key_forms"] = card["forms"].replace("\n", "; ")
    return d


def process_batch(batch: list[dict], args, checker: Checker, deck_words: set[str], api_key: str | None) -> tuple[dict, dict]:
    variety = VARIETIES[args.variety]
    prompt = GENERATE.format(variety=variety, n=args.per_word, situations=", ".join(SITUATIONS),
                             words=json.dumps([describe_card(c, args.per_word) for c in batch], ensure_ascii=False, indent=1))
    result, usage1 = ask(args, SYSTEM, prompt, max_tokens=350 * args.per_word * len(batch) + 500, api_key=api_key)
    by_id = {c["id"]: c for c in batch}
    candidates, dropped = [], []
    for w in result.get("words", []):
        card = by_id.get(w.get("id"))
        if not card:
            continue
        seen = set()
        for ph in w.get("phrases", []):
            reason = checker.check(card, ph, deck_words)
            key = ph.get("es", "").strip().lower()
            if not reason and key in seen:
                reason = "duplicate"
            if reason:
                dropped.append((card["id"], ph.get("es", ""), reason)); continue
            seen.add(key)
            pid = dict_tools.phrase_id(ph["es"])
            situation = ph.get("situation") if ph.get("situation") in SITUATIONS else "everyday"
            form = (ph.get("form") or "").strip().strip("¿?¡!.,;: ") or None
            if form and not dict_tools.find_in_sentence(ph["es"], form):
                form = None
            clean = {"id": pid, "es": ph["es"].strip(), "en": ph["en"].strip(), "situation": situation,
                     "form": form, "source": "ai",
                     "meaning": int(ph.get("meaning") or 0)}
            if (note := checker.note_for(card, ph)):
                clean["note"] = note
            candidates.append((card["id"], {k: v for k, v in clean.items() if v is not None}))

    # Second pass: review.
    usage2 = {}
    if candidates and not args.no_review:
        items = [{"pid": ph["id"], "word": by_id[cid]["spanish"],
                  "meaning": ([by_id[cid]["english"]] + [m["english"] for m in by_id[cid].get("otherMeanings") or []])[min(ph["meaning"], len(by_id[cid].get("otherMeanings") or []))],
                  "es": ph["es"], "en": ph["en"], "note": ph.get("note", "")} for cid, ph in candidates]
        verdicts, usage2 = ask(args, "Return only JSON.",
                               REVIEW_PROMPT.format(variety_short=args.variety, items=json.dumps(items, ensure_ascii=False, indent=1)),
                               max_tokens=60 * len(items) + 300, api_key=api_key, model=args.review_model or args.model)
        ok = {v["pid"] for v in verdicts.get("verdicts", []) if v.get("ok") is True}
        reasons = {v["pid"]: v.get("reason", "") for v in verdicts.get("verdicts", [])}
        kept = []
        for cid, ph in candidates:
            if ph["id"] in ok:
                kept.append((cid, ph))
            else:
                dropped.append((cid, ph["es"], "review: " + (reasons.get(ph["id"]) or "not approved")))
        candidates = kept

    out: dict[str, list[dict]] = {c["id"]: [] for c in batch}
    for cid, ph in candidates:
        out[cid].append(ph)
    usage = {"input": usage1.get("input_tokens", 0) + usage2.get("input_tokens", 0),
             "output": usage1.get("output_tokens", 0) + usage2.get("output_tokens", 0), "dropped": dropped}
    return out, usage


def cache_path(card_id: str, args) -> pathlib.Path:
    return CACHE / f"{card_id}.json"


def signature(card: dict) -> str:
    """Changes when the card's word, meanings or level change → its phrases are regenerated."""
    meanings = [card["english"]] + [m["english"] for m in card.get("otherMeanings") or []]
    return json.dumps([PROMPT_VERSION, card["spanish"], card["level"], meanings], ensure_ascii=False)


def is_current(card: dict, args) -> bool:
    path = cache_path(card["id"], args)
    if not path.exists():
        return False
    try:
        return json.loads(path.read_text(encoding="utf-8")).get("signature") == signature(card)
    except (json.JSONDecodeError, OSError):
        return False


def estimate(cards: list[dict], args) -> float:
    per_word_in = 260 + 90 * args.per_word            # prompt share + review input
    per_word_out = 90 * args.per_word + 15 * args.per_word
    pin, pout = PRICES.get(args.model, PRICES["claude-sonnet-5-5"])
    return len(cards) * (per_word_in * pin + per_word_out * pout) / 1e6


def write_review(deck: list[dict], phrases: dict[str, list[dict]]) -> None:
    lines = ["# Novice phrases to review",
             "",
             "Skim these. To drop one, add its id to `tools/phrases_rejected.txt` and re-run "
             "`python3 tools/import_dictionary.py --merge-only`.",
             ""]
    for card in deck:
        if card["level"] != "novice" or not phrases.get(card["id"]):
            continue
        lines.append(f"## {card['spanish']} — {card['english']}")
        for ph in phrases[card["id"]]:
            lines.append(f"- `{ph['id']}` [{ph.get('situation', '')}] **{ph['es']}** — {ph['en']}"
                         + (f"  \n  _{ph['note']}_" if ph.get("note") else ""))
        lines.append("")
    REVIEW.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--levels", default="novice,beginner,intermediate,fluent")
    ap.add_argument("--limit", type=int, help="at most this many words this run")
    ap.add_argument("--per-word", type=int, default=4)
    ap.add_argument("--batch", type=int, default=8, help="words per API call")
    ap.add_argument("--workers", type=int, help="parallel requests (default 4 for api, 2 for claude-code)")
    ap.add_argument("--backend", choices=["api", "claude-code"], default="api",
                    help="api = Anthropic API key (Max plans include monthly API credits); "
                         "claude-code = `claude -p` signed in with your plan (uses plan usage limits)")
    ap.add_argument("--model", default="claude-sonnet-5-5")
    ap.add_argument("--review-model", help="model for the review pass (default: same as --model)")
    ap.add_argument("--no-review", action="store_true", help="skip the second check pass (not recommended)")
    ap.add_argument("--variety", default="es-MX", choices=sorted(VARIETIES))
    ap.add_argument("--redo", action="store_true", help="ignore cached results")
    ap.add_argument("--dry-run", action="store_true", help="show what would run and the estimated cost")
    ap.add_argument("--yes", action="store_true", help="don't ask before spending")
    args = ap.parse_args()

    deck = json.loads(dict_tools.DECK.read_text(encoding="utf-8"))
    levels = set(args.levels.split(","))
    CACHE.mkdir(parents=True, exist_ok=True)
    todo = [c for c in deck if c["level"] in levels and (args.redo or not is_current(c, args))]
    # Most useful first: novice before fluent, then deck order (frequency).
    order = {"novice": 0, "beginner": 1, "intermediate": 2, "fluent": 3}
    todo.sort(key=lambda c: order.get(c["level"], 9))
    if args.limit:
        todo = todo[: args.limit]

    workers = args.workers or (2 if args.backend == "claude-code" else 4)
    if args.backend == "claude-code":
        print(f"{len(todo):,} words to write phrases for ({args.per_word} each, model {args.model}) "
              f"through Claude Code — uses your Claude plan's usage limits, no API charges.")
    else:
        print(f"{len(todo):,} words to write phrases for ({args.per_word} each, model {args.model}). "
              f"Estimated cost ≈ ${estimate(todo, args):,.2f} (Max plans' monthly API credits cover this)")
    if args.dry_run or not todo:
        finish(deck)
        return
    api_key = None
    if args.backend == "claude-code":
        if not shutil.which("claude"):
            sys.exit("Claude Code isn't installed (https://docs.claude.com/en/docs/claude-code/overview), "
                     "or use --backend api.")
        if os.environ.get("ANTHROPIC_API_KEY"):
            print("  Note: ANTHROPIC_API_KEY is set; it's ignored for this run so Claude Code uses your plan.")
    else:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            sys.exit("Set ANTHROPIC_API_KEY first (platform.claude.com → API keys), or use --backend claude-code.")
    if not args.yes and input("Continue? [y/N] ").strip().lower() != "y":
        return

    checker = Checker()
    deck_words = {t for c in deck for t in dict_tools.tokens(c["spanish"])}
    for c in deck:
        deck_words |= {v.lower() for v in dict_tools.form_values(c.get("forms"))}
    batches = [todo[i:i + args.batch] for i in range(0, len(todo), args.batch)]
    spent_in = spent_out = kept = dropped_total = 0
    drop_log = dict_tools.CACHE / "phrases_dropped.tsv"
    stopped = False
    with futures.ThreadPoolExecutor(max_workers=workers) as pool, open(drop_log, "a", encoding="utf-8") as log:
        jobs = {pool.submit(process_batch, b, args, checker, deck_words, api_key): b for b in batches}
        for n, job in enumerate(futures.as_completed(jobs), 1):
            batch = jobs[job]
            try:
                out, usage = job.result()
            except UsageLimitReached as err:
                if not stopped:
                    print(f"\n  Claude plan usage limit reached ({err}). Saving progress — re-run later to continue.")
                    stopped = True
                    for other in jobs:
                        other.cancel()
                continue
            except futures.CancelledError:
                continue
            except Exception as err:      # keep going; failed words are retried next run
                print(f"\n  batch failed ({', '.join(c['spanish'] for c in batch)}): {err}")
                continue
            by_id = {c["id"]: c for c in batch}
            for cid, phrases in out.items():
                cache_path(cid, args).write_text(json.dumps(
                    {"version": PROMPT_VERSION, "signature": signature(by_id[cid]), "model": args.model,
                     "phrases": phrases}, ensure_ascii=False), encoding="utf-8")
                kept += len(phrases)
            for cid, es, reason in usage["dropped"]:
                log.write(f"{cid}\t{es}\t{reason}\n")
            dropped_total += len(usage["dropped"])
            spent_in += usage["input"]; spent_out += usage["output"]
            pin, pout = PRICES.get(args.model, (0, 0)) if args.backend == "api" else (0, 0)
            spent = f" · ${(spent_in * pin + spent_out * pout) / 1e6:,.2f}" if args.backend == "api" else ""
            print(f"\r  {n}/{len(batches)} batches · {kept:,} phrases kept · {dropped_total:,} dropped{spent}",
                  end="", flush=True)
    print(f"\nDropped phrases and reasons: {drop_log.relative_to(ROOT)}")
    finish(deck)


def finish(deck: list[dict]) -> None:
    phrases = {}
    cards = {c["id"]: c for c in deck}
    for f in sorted(CACHE.glob("*.json")) if CACHE.exists() else []:
        data = json.loads(f.read_text(encoding="utf-8"))
        card = cards.get(f.stem)
        # Skip phrases for cards that no longer exist or whose meanings changed since they were
        # written. Phrases from before signatures existed stay until that word is regenerated.
        if card and data.get("phrases") and data.get("signature") in (None, signature(card)):
            phrases[f.stem] = data["phrases"]
    if phrases or OUTPUT.exists():
        OUTPUT.write_text(json.dumps(phrases, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        write_review(deck, phrases)
        print(f"{sum(len(v) for v in phrases.values()):,} phrases for {len(phrases):,} words → "
              f"{OUTPUT.relative_to(ROOT)} (review: {REVIEW.relative_to(ROOT)})")
    if not REJECTED.exists():
        REJECTED.write_text("# Phrase ids to drop, one per line (see tools/phrases_review.md)\n", encoding="utf-8")
    dict_tools.merge()


if __name__ == "__main__":
    main()
