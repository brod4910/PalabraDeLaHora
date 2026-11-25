#!/usr/bin/env python3
"""
Sanity-checks the deck (Shared/words.json) and the last phrase run, and writes a report.

    python3 tools/sanity_check.py            # report → tools/.cache/sanity_report.md
    python3 tools/sanity_check.py --strict   # exit 1 if anything serious is found (for pre-commit)

Mechanical checks only — it finds *suspects*; a human (or Claude, with the palabra sanity-check
skill) still judges the Spanish. Standard library only.

Deck checks
  • duplicates that differ only by accents (cual / cuál, mas / más)
  • cards that look like a form of another card's word (comido ↔ comer, cuentas ↔ contar)
  • meanings that are filler words only ("the", "to be"), untranslated, or too long
  • example sentences that don't contain the highlighted word; notes whose form isn't in the sentence
  • verbs/nouns/adjectives without key forms; verb tables missing yo/tú/él
  • grammar-note smells ("command" on an -í past tense, a pronoun split on a non-verb)
  • everyday phrases that don't contain their word, duplicate, too long, or with an unknown situation
Phrase-run checks (tools/.cache/phrases_dropped.tsv)
  • drop reasons by category, and the words with the most drops (usually a card problem, not a
    phrase problem)
  • review reasons grouped by cause: wrong meaning on the card, wrong grammar note, regional or
    unnatural usage
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import unicodedata
from collections import Counter, defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
DECK = ROOT / "Shared" / "words.json"
CACHE = ROOT / "tools" / ".cache"
DROPPED = CACHE / "phrases_dropped.tsv"
REPORT = CACHE / "sanity_report.md"

SITUATIONS = {"home", "food", "shopping", "work", "travel", "texting", "family", "friends", "couple",
              "feelings", "health", "plans", "weather", "school", "everyday"}
FILLER = {"to", "a", "an", "the", "of", "be", "is", "it", "one", "or", "and", "in", "on", "for", "with", "as"}
WORD = re.compile(r"[a-záéíóúüñ]+", re.IGNORECASE)
VERB_END = re.compile(r"(ar|er|ir|ír)(se)?$")
FORM_ENDINGS = ("ado", "ada", "ados", "adas", "ido", "ida", "idos", "idas", "aron", "ieron", "amos", "emos",
                "imos", "aste", "iste", "ando", "iendo")


def fold(s: str) -> str:
    return unicodedata.normalize("NFD", s.lower()).encode("ascii", "ignore").decode()


def tokens(s: str) -> list[str]:
    return [t.lower() for t in WORD.findall(s)]


def contains(sentence: str, word: str) -> bool:
    return bool(re.search(rf"(?<![a-záéíóúüñ]){re.escape(word)}(?![a-záéíóúüñ])", sentence, re.IGNORECASE))


class Report:
    def __init__(self) -> None:
        self.sections: list[tuple[str, str, list[str]]] = []   # (severity, title, lines)

    def add(self, severity: str, title: str, items: list[str], limit: int = 25, count: int | None = None) -> None:
        if not items:
            return
        shown = items[:limit] + ([f"… and {len(items) - limit} more"] if len(items) > limit else [])
        self.sections.append((severity, f"{title} ({count if count is not None else len(items)})", shown))

    @property
    def serious(self) -> int:
        return sum(1 for sev, _, _ in self.sections if sev == "error")


def check_deck(deck: list[dict], r: Report) -> dict:
    by_fold = defaultdict(list)
    for c in deck:
        by_fold[fold(c["spanish"])].append(c)
    r.add("warn", "Cards that differ only by accents (likely one is a typo or a rare literary word)",
          [" / ".join(f"`{c['spanish']}` ({c['english']}, {c.get('source', '?')})" for c in cs)
           for cs in by_fold.values() if len(cs) > 1])

    words = {c["spanish"].lower(): c for c in deck if c["kind"] == "word"}
    verbs = {w: c for w, c in words.items() if c["partOfSpeech"].startswith("verb") and VERB_END.search(w)}
    stems = defaultdict(list)
    for v in verbs:
        stems[fold(VERB_END.sub("", v))].append(v)
    def keys(text: str) -> set[str]:
        return {t[:4] for t in re.findall(r"[a-z]+", text.lower()) if t not in FILLER and len(t) > 2}

    looks_like_forms = []
    for w, c in words.items():
        if w in verbs or c.get("source") == "curated":
            continue
        for end in FORM_ENDINGS:
            if fold(w).endswith(end) and (base := stems.get(fold(w)[: -len(end)])):
                # Only when the meaning just restates the verb (comido "eaten" ↔ comer "eat"):
                # comida "food" and llamada "call" are real nouns.
                if any(keys(c["english"]) & keys(words[b]["english"]) for b in base):
                    looks_like_forms.append(f"`{w}` ({c['english']}) — looks like a form of {', '.join(base)}")
                break
    r.add("info", "Participle-like cards (fine as adjectives like casado or preocupado; "
                  "fold into the verb if the meaning is just the verb's)", looks_like_forms)

    bad_meanings, untranslated = [], []
    function_pos = ("preposition", "conjunction", "article", "determiner", "pronoun", "number", "adverb")
    for c in deck:
        for m in [c["english"]] + [x["english"] for x in c.get("otherMeanings") or []]:
            content = [t for t in re.findall(r"[a-z]+", m.lower()) if t not in FILLER]
            t = m.strip()
            if (len(t) == 1 and t.isalpha()) or (t.isupper() and len(t) <= 2) or \
               (len(t) <= 2 and not c["partOfSpeech"].startswith(function_pos) and t.lower() not in FILLER):
                bad_meanings.append(f"`{c['spanish']}` ({c['partOfSpeech']}) → “{m}” looks like a letter or musical note")
            elif not content and not c["partOfSpeech"].startswith(function_pos):
                # de = "of", y = "and" are fine; a noun or verb meaning "the" is not.
                bad_meanings.append(f"`{c['spanish']}` ({c['partOfSpeech']}) → “{m}” is only filler words")
            elif fold(m) == fold(c["spanish"]) and c["kind"] == "word":
                untranslated.append(f"`{c['spanish']}` ({c['partOfSpeech']}) → “{m}”")
            elif len(m) > 45:
                bad_meanings.append(f"`{c['spanish']}` → “{m}” is very long")
    r.add("error", "Suspicious meanings", bad_meanings)
    r.add("warn", "Meaning same as the Spanish word (fine for cognates like idea or hotel; "
                  "wrong for false matches like son = son)", untranslated)

    example_issues = []
    for c in deck:
        for label, ex, word, note in [("example", c["example"], c.get("exampleWord"), c.get("exampleNote"))] + [
                (f"meaning “{m['english']}”", m.get("example") or "", m.get("exampleWord"), m.get("exampleNote"))
                for m in c.get("otherMeanings") or []]:
            if word and not contains(ex, word):
                example_issues.append(f"`{c['spanish']}` {label}: highlighted “{word}” not in “{ex}”")
            if note:
                bold = re.findall(r"\*\*(.+?)\*\*", note)
                if bold and not contains(ex, bold[0].strip("¡!¿?")) and " " not in bold[0]:
                    example_issues.append(f"`{c['spanish']}` {label}: note is about “{bold[0]}” but the sentence is “{ex}”")
    r.add("error", "Examples that don't match their highlight or note", example_issues)

    note_smells = []
    for c in deck:
        notes = [(c.get("exampleWord") or "", c.get("exampleNote") or "")]
        notes += [(p.get("form") or "", p.get("note") or "") for p in c.get("phrases") or []]
        for form, note in notes:
            if not note:
                continue
            f = form.lower()
            if "command" in note and re.search(r"[íé]$", f) and "+" not in note:
                note_smells.append(f"`{c['spanish']}`: “{form}” called a command (probably a past tense, vos reading)")
            if re.search(r"= \*\w+\* \(.*\) \+ \*(la|lo|las|los|le|les|me|te|se|nos)\*", note) and not VERB_END.search(c["spanish"]):
                note_smells.append(f"`{c['spanish']}`: pronoun split on a non-verb — {note[:90]}")
            if "a form" in note and "for" not in note:
                note_smells.append(f"`{c['spanish']}`: vague note “{note[:80]}”")
    r.add("error", "Grammar notes that look wrong", note_smells)

    missing_forms = defaultdict(list)
    incomplete = []
    for c in deck:
        pos = c["partOfSpeech"].split(" ")[0]
        if c["kind"] == "word" and pos in {"verb", "noun", "adjective", "determiner"} and not c.get("forms"):
            missing_forms[pos].append(c["spanish"])
        if pos == "verb" and c.get("forms"):
            labels = {line.split(": ", 1)[0] for line in c["forms"].split("\n") if ": " in line}
            if not ({"yo", "tú", "él / ella"} <= labels or {"a mí", "a ti"} <= labels):
                incomplete.append(f"`{c['spanish']}`: {', '.join(sorted(labels))}")
    r.add("warn", "Cards without key forms", [f"{pos}: {', '.join(ws[:30])}{' …' if len(ws) > 30 else ''} ({len(ws)})"
                                             for pos, ws in missing_forms.items()],
          count=sum(len(ws) for ws in missing_forms.values()))
    r.add("warn", "Verb tables missing yo / tú / él", incomplete)

    phrase_issues = []
    for c in deck:
        seen = set()
        for p in c.get("phrases") or []:
            key = " ".join(tokens(fold(p["es"])))
            if key in seen:
                phrase_issues.append(f"`{c['spanish']}`: duplicate phrase “{p['es']}”")
            seen.add(key)
            if p.get("form") and not contains(p["es"], p["form"]) and not contains(p["es"], p["form"].strip("¿?¡!.,")):
                phrase_issues.append(f"`{c['spanish']}`: form “{p['form']}” not in “{p['es']}” ({p['id']})")
            if len(tokens(p["es"])) > 12:
                phrase_issues.append(f"`{c['spanish']}`: long phrase ({len(tokens(p['es']))} words) “{p['es']}”")
            if p.get("situation") and p["situation"] not in SITUATIONS:
                phrase_issues.append(f"`{c['spanish']}`: unknown situation “{p['situation']}”")
            if not p.get("en"):
                phrase_issues.append(f"`{c['spanish']}`: phrase without translation “{p['es']}”")
    r.add("error", "Everyday phrase problems", phrase_issues)

    stats = {
        "cards": len(deck),
        "by_level": Counter(c["level"] for c in deck),
        "by_source": Counter(c.get("source", "?") for c in deck),
        "with_forms": sum(1 for c in deck if c.get("forms")),
        "with_phrases": sum(1 for c in deck if c.get("phrases")),
        "ai_phrases": sum(1 for c in deck for p in c.get("phrases") or [] if p.get("source") == "ai"),
        "real_phrases": sum(1 for c in deck for p in c.get("phrases") or [] if p.get("source") == "tatoeba"),
        "multi_meaning": sum(1 for c in deck if c.get("otherMeanings")),
    }
    novice_without = [c["spanish"] for c in deck if c["level"] == "novice" and not c.get("phrases")]
    r.add("warn", "Novice cards without any everyday phrase", [", ".join(novice_without)] if novice_without else [],
          count=len(novice_without))
    return stats


REVIEW_CAUSES = [
    ("Card meaning is wrong or rare (fix the importer's meaning choice)",
     r"stated meaning|doesn't match the|not the stated|different sense|meaning label|gloss|does not mean|doesn't mean"),
    ("Grammar note is wrong (fix the analyzer)", r"\bnote\b"),
    ("Regional usage (Spain / South America / not es-MX)", r"es-MX|Mexic|Spain|South American|vosotros|regional"),
    ("Archaic, literary or formal", r"archaic|literary|biblical|formal"),
    ("Not a real word or wrong word", r"not a real|not a spanish|is not a word|ungrammatical"),
    ("Unnatural / calque / translation off",
     r"unnatural|not natural|calque|awkward|translation|redundant|stilted|odd|nobody says|stiff|not the natural|wrong|incomplete|imprecise"),
]


def check_drops(r: Report) -> dict:
    if not DROPPED.exists():
        return {}
    rows = [line.rstrip("\n").split("\t") for line in DROPPED.read_text(encoding="utf-8").splitlines() if line.strip()]
    rows = [x for x in rows if len(x) >= 3]
    reasons = Counter(re.split(r"[:']", x[2])[0].strip() or x[2] for x in rows)
    per_word = Counter(x[0] for x in rows)
    r.add("info", "Drop reasons", [f"{n:>5}  {reason}" for reason, n in reasons.most_common()])
    r.add("warn", "Words with 3+ dropped phrases (usually the card is the problem)",
          [f"`{w}`: {n} — e.g. “{next(x[1] for x in rows if x[0] == w)}”" for w, n in per_word.most_common() if n >= 3])
    grouped = defaultdict(list)
    for w, es, reason in ((x[0], x[1], x[2]) for x in rows if x[2].startswith("review")):
        for title, pattern in REVIEW_CAUSES:
            if re.search(pattern, reason, re.IGNORECASE):
                grouped[title].append(f"`{w}` “{es}” — {reason[8:][:110]}")
                break
        else:
            grouped["Other"].append(f"`{w}` “{es}” — {reason[8:][:110]}")
    for title, items in grouped.items():
        r.add("info", f"Review rejections: {title}", items, limit=12)
    return {"dropped": len(rows), "reasons": reasons}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--strict", action="store_true", help="exit 1 if serious problems are found")
    args = ap.parse_args()

    deck = json.loads(DECK.read_text(encoding="utf-8"))
    r = Report()
    stats = check_deck(deck, r)
    drops = check_drops(r)

    lines = ["# Deck sanity report", "",
             f"- **{stats['cards']:,} cards** — " + ", ".join(f"{k} {v:,}" for k, v in stats["by_level"].items()),
             f"- sources: " + ", ".join(f"{k} {v:,}" for k, v in stats["by_source"].items()),
             f"- key forms on {stats['with_forms']:,} · several meanings on {stats['multi_meaning']:,}",
             f"- everyday phrases on {stats['with_phrases']:,} cards ({stats['ai_phrases']:,} AI, "
             f"{stats['real_phrases']:,} real sentences)"]
    if drops:
        lines.append(f"- last phrase run: {drops['dropped']:,} phrases dropped")
    icon = {"error": "🔴", "warn": "🟡", "info": "ℹ️"}
    for sev in ("error", "warn", "info"):
        for s, title, items in r.sections:
            if s == sev:
                lines += ["", f"## {icon[s]} {title}", ""] + [f"- {i}" for i in items]
    CACHE.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print("\n".join(lines[:7]))
    for s, title, _ in r.sections:
        print(f"  {icon[s]} {title}")
    print(f"\nFull report: {REPORT.relative_to(ROOT)}")
    if args.strict and r.serious:
        sys.exit(f"{r.serious} serious problem group(s) — see the report.")


if __name__ == "__main__":
    main()
