#!/usr/bin/env python3
"""
Builds Palabra's deck from open dictionary data, then merges in the hand-written cards.

    python3 tools/import_dictionary.py                 # download (first run only) + build ~5,000 cards
    python3 tools/import_dictionary.py --count 8000    # bigger deck
    python3 tools/import_dictionary.py --merge-only    # just re-merge curated + generated → Shared/words.json

Sources (downloaded into tools/.cache/, which is git-ignored):
  • Word frequency — FrequencyWords (OpenSubtitles 2018), Hermit Dave, CC BY-SA 4.0
        which words people actually say, in order → also decides the level
  • Meanings + word forms — English Wiktionary via Wiktextract / kaikki.org (Tatu Ylonen), CC BY-SA
  • Example sentences — Tatoeba (tatoeba.org), CC BY 2.0 FR
        short real sentences with human English translations, preferring easy vocabulary

Only the Python 3 standard library is used. The first run downloads ~1–3 GB and takes a while;
the filtered subsets are cached, so later runs take seconds.

Per card:
  spanish / english / partOfSpeech  ← Wiktionary; vulgar/offensive words skipped. Words with several
                                      meanings (cuarto = room / fourth) get up to 3, each with its own
                                      example; most-used meaning first (counted in Tatoeba)
  phonetic                          ← generated from Spanish spelling (it's regular), e.g. keh-REHR
  example / exampleTranslation      ← Tatoeba, only sentences whose English uses that meaning
                                      (fallback: Wiktionary's example for that exact sense)
  forms ("Key forms")               ← Wiktionary inflections, one "label: value" per line:
                                      yo: tengo / tú: tienes / él / ella: tiene / past (yo): tuve,
                                      singular: la casa / plural: las casas, adjective endings
  level                             ← frequency rank: ≤600 novice, ≤1500 beginner, ≤3000 intermediate, else fluent
"""
from __future__ import annotations

import argparse
import bz2
import gzip
import io
import json
import pathlib
import re
import sys
import tarfile
import unicodedata
import urllib.request
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
CACHE = TOOLS / ".cache"
CURATED = TOOLS / "curated.json"
GENERATED = TOOLS / "generated.json"
DECK = ROOT / "Shared" / "words.json"

FREQ_URL = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/es/es_50k.txt"
KAIKKI_URLS = [
    # Per-language extract (≈1 GB). Marked deprecated by kaikki.org but still served.
    ("https://kaikki.org/dictionary/Spanish/kaikki.org-dictionary-Spanish.jsonl", False),
    # Fallback: the whole English Wiktionary extraction (≈2.9 GB gz), filtered to Spanish while streaming.
    ("https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz", True),
]
TATOEBA_PER_LANGUAGE = {
    "spa": "https://downloads.tatoeba.org/exports/per_language/spa/spa_sentences.tsv.bz2",
    "eng": "https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2",
    "links": "https://downloads.tatoeba.org/exports/per_language/spa/spa-eng_links.tsv.bz2",
}
TATOEBA_FULL = {
    "sentences": "https://downloads.tatoeba.org/exports/sentences.tar.bz2",
    "links": "https://downloads.tatoeba.org/exports/links.tar.bz2",
}

LEVEL_CUTOFFS = [(600, "novice"), (1500, "beginner"), (3000, "intermediate")]
BLOCKED_TAGS = {"vulgar", "offensive", "derogatory", "slur", "ethnic", "pejorative", "sexual"}
WEAK_TAGS = {"obsolete", "archaic", "rare", "dated", "historical", "uncommon", "nonstandard", "misspelling"}
POS_LABELS = {
    "verb": "verb", "noun": "noun", "adj": "adjective", "adv": "adverb", "pron": "pronoun",
    "prep": "preposition", "conj": "conjunction", "intj": "interjection", "num": "number",
    "det": "determiner", "article": "article", "phrase": "phrase", "contraction": "contraction",
}
POS_PRIORITY = ["verb", "noun", "adj", "adv", "pron", "prep", "conj", "det", "article", "num", "intj", "phrase", "contraction"]


# ─────────────────────────────────────────────────────────────── downloads

def download(url: str, dest: pathlib.Path) -> pathlib.Path:
    if dest.exists() and dest.stat().st_size > 0:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    print(f"↓ {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "Palabra-deck-builder/1.0"})
    with urllib.request.urlopen(req) as r, open(tmp, "wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        done = 0
        while chunk := r.read(1 << 20):
            f.write(chunk)
            done += len(chunk)
            if total:
                print(f"\r  {done / 1e6:,.0f} / {total / 1e6:,.0f} MB", end="", flush=True)
            else:
                print(f"\r  {done / 1e6:,.0f} MB", end="", flush=True)
    print()
    tmp.rename(dest)
    return dest


def open_text(path: pathlib.Path):
    if path.suffix == ".gz":
        return io.TextIOWrapper(gzip.open(path, "rb"), encoding="utf-8")
    if path.suffix == ".bz2":
        return io.TextIOWrapper(bz2.open(path, "rb"), encoding="utf-8")
    return open(path, encoding="utf-8")


# ─────────────────────────────────────────────────────────────── text helpers

def slug(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


TOKEN = re.compile(r"[a-záéíóúüñ]+", re.IGNORECASE)


def tokens(s: str) -> list[str]:
    return [t.lower() for t in TOKEN.findall(s)]


# ─────────────────────────────────────────────────────────────── pronunciation

VOWELS = set("aeiouáéíóúü")
STRONG = set("aeoáéíóú")
ACCENTED = set("áéíóú")
CLUSTERS = {"pr", "br", "tr", "dr", "cr", "kr", "gr", "fr", "pl", "bl", "cl", "kl", "gl", "fl"}


def syllabify(word: str) -> list[str]:
    """Same rules as Shared/SlowSpeech.swift (Syllables.split)."""
    ch = list(word.lower())
    toks, i = [], 0
    while i < len(ch):
        c = ch[i]
        n = ch[i + 1] if i + 1 < len(ch) else None
        a = ch[i + 2] if i + 2 < len(ch) else None
        if n and c + n in ("ch", "ll", "rr"):
            toks.append((c + n, False)); i += 2; continue
        if c in "qg" and n == "u" and a and a in "eiéí":
            toks.append((c + "u", False)); i += 2; continue
        toks.append((c, c in VOWELS or (c == "y" and n is None)))
        i += 1
    parts, cons, vr = [], [], []

    def flush():
        nonlocal cons, vr
        if not vr:
            return
        if cons or not parts:
            parts.append(("c", cons))
        cons = []
        g = vr[0]
        for k in range(1, len(vr)):
            if vr[k - 1] in STRONG and vr[k] in STRONG:
                parts.append(("n", g)); parts.append(("c", [])); g = vr[k]
            else:
                g += vr[k]
        parts.append(("n", g)); vr = []

    for x, v in toks:
        if v:
            vr.append(x)
        else:
            if vr:
                flush()
            cons.append(x)
    flush()
    if cons:
        parts.append(("c", cons))
    syl, cur, idx = [], "", 0
    if parts and parts[0][0] == "c":
        cur = "".join(parts[0][1]); idx = 1
    while idx < len(parts):
        if parts[idx][0] != "n":
            idx += 1; continue
        cur += parts[idx][1]
        f = parts[idx + 1][1] if idx + 1 < len(parts) and parts[idx + 1][0] == "c" else []
        if idx + 2 >= len(parts):
            syl.append(cur + "".join(f)); cur = ""; break
        c = f
        if len(c) == 0: co, on = [], []
        elif len(c) == 1: co, on = [], c
        elif len(c) == 2: co, on = ([], c) if c[0] + c[1] in CLUSTERS else ([c[0]], [c[1]])
        elif len(c) == 3: co, on = ([c[0]], c[1:]) if c[1] + c[2] in CLUSTERS else (c[:2], [c[2]])
        else: co, on = c[:-2], c[-2:]
        syl.append(cur + "".join(co)); cur = "".join(on); idx += 2
    if cur:
        if syl: syl[-1] += cur
        else: syl.append(cur)
    return syl or [word]


VOWEL_SOUNDS = {
    "a": "ah", "e": "eh", "i": "ee", "o": "oh", "u": "oo", "ü": "oo",
    "ie": "yeh", "ia": "yah", "io": "yoh", "iu": "yoo", "ue": "weh", "ua": "wah", "uo": "woh", "ui": "wee",
    "üe": "weh", "üi": "wee", "ai": "eye", "ay": "eye", "ei": "ay", "ey": "ay", "oi": "oy", "oy": "oy",
    "au": "ow", "eu": "eh-oo", "uy": "wee", "ou": "oh", "uay": "wye", "uey": "way", "iai": "yeye", "iei": "yay",
}


def strip_accents(s: str) -> str:
    """Removes only the acute accent (á → a); keeps ñ and ü."""
    return unicodedata.normalize("NFC", unicodedata.normalize("NFD", s).replace("\u0301", ""))


def respell_syllable(s: str, word_initial: bool, prev_coda: str) -> str:
    out, i = [], 0
    plain = strip_accents(s)
    while i < len(plain):
        c = plain[i]
        n = plain[i + 1] if i + 1 < len(plain) else ""
        if c in "aeiouü" or (c == "y" and i == len(plain) - 1 and i > 0 and plain[i - 1] in "aeiou"):
            j = i
            while j < len(plain) and (plain[j] in "aeiouü" or (plain[j] == "y" and j == len(plain) - 1 and j > i)):
                j += 1
            nucleus = plain[i:j]
            out.append(VOWEL_SOUNDS.get(nucleus) or "".join(VOWEL_SOUNDS.get(v, v) for v in nucleus))
            i = j
            continue
        two = plain[i:i + 2]
        if two == "ch": out.append("ch"); i += 2; continue
        if two == "ll": out.append("y"); i += 2; continue
        if two == "rr": out.append("rr"); i += 2; continue
        if two == "qu": out.append("k"); i += 2; continue
        if two == "gu" and plain[i + 2:i + 3] in ("e", "i"): out.append("g"); i += 2; continue
        if two == "gü": out.append("gw"); i += 2; continue
        if c == "c": out.append("s" if n in ("e", "i") else "k")
        elif c == "g": out.append("h" if n in ("e", "i") else "g")
        elif c == "j": out.append("h")
        elif c == "h": pass
        elif c == "ñ": out.append("ny")
        elif c == "z": out.append("s")
        elif c == "v": out.append("b")
        elif c == "x": out.append("ks")
        elif c == "r" and i == 0 and (word_initial or prev_coda in ("l", "n", "s")): out.append("rr")
        else: out.append(c)
        i += 1
    return "".join(out)


def respell_word(word: str) -> str:
    if word.lower() == "y":
        return "ee"
    syl = syllabify(word)
    if len(syl) == 1:
        return respell_syllable(syl[0], True, "")
    stressed = next((k for k, s in enumerate(syl) if any(ch in ACCENTED for ch in s)), None)
    if stressed is None:
        last = strip_accents(word.lower())[-1:]
        stressed = len(syl) - 2 if last in "aeiouns" else len(syl) - 1
    parts = []
    for k, s in enumerate(syl):
        prev = strip_accents(syl[k - 1])[-1:] if k else ""
        r = respell_syllable(s, k == 0, prev)
        if r.startswith("ks") and parts:          # éxito: EHK-see-toh, not EH-ksee-toh
            parts[-1] += "k"; r = r[1:]
        parts.append(r)
    parts = [r.upper() if k == stressed else r for k, r in enumerate(parts)]
    return "-".join(parts)


def respell(text: str) -> str:
    return " ".join(respell_word(w) for w in tokens(text)) or text


# ─────────────────────────────────────────────────────────────── frequency

def load_frequency(path: pathlib.Path) -> list[tuple[str, int]]:
    out, seen = [], set()
    with open_text(path) as f:
        for line in f:
            parts = line.split()
            if len(parts) != 2:
                continue
            w = parts[0].lower()
            if w in seen or not re.fullmatch(r"[a-záéíóúüñ]+", w):
                continue
            if len(w) == 1 and w not in ("a", "y", "o", "e", "u"):
                continue
            seen.add(w)
            out.append((w, int(parts[1])))
    return out


# ─────────────────────────────────────────────────────────────── Wiktionary (kaikki)

WORD_FIELD = re.compile(r'"word":\s*"((?:[^"\\]|\\.)*)"')


def kaikki_subset(wanted: set[str], source: pathlib.Path, is_raw: bool, subset: pathlib.Path) -> None:
    """Streams the big dump once, keeping Spanish entries whose headword is in `wanted`."""
    print(f"Scanning {source.name} for {len(wanted):,} headwords… (one-time, a few minutes)")
    kept = 0
    with open_text(source) as f, open(subset, "a", encoding="utf-8") as out:
        for n, line in enumerate(f, 1):
            if is_raw and '"lang_code": "es"' not in line:
                continue
            m = WORD_FIELD.search(line)
            if not m:
                continue
            try:
                w = json.loads(f'"{m.group(1)}"').lower()
            except json.JSONDecodeError:
                continue
            if w not in wanted:
                continue
            e = json.loads(line)
            if e.get("lang_code", "es") != "es":
                continue
            out.write(json.dumps(e, ensure_ascii=False) + "\n")
            kept += 1
            if n % 200_000 == 0:
                print(f"\r  {n:,} lines, {kept:,} kept", end="", flush=True)
    print(f"\r  kept {kept:,} entries" + " " * 20)


def load_entries(subset: pathlib.Path) -> dict[str, list[dict]]:
    by_word: dict[str, list[dict]] = defaultdict(list)
    if subset.exists():
        with open(subset, encoding="utf-8") as f:
            for line in f:
                e = json.loads(line)
                by_word[e["word"].lower()].append(e)
    return by_word


def sense_tags(sense: dict) -> set[str]:
    tags = set(sense.get("tags", []))
    for raw in sense.get("raw_tags", []) or []:
        tags.update(raw.lower().split())
    return tags


def is_blocked(entries: list[dict]) -> bool:
    for e in entries:
        for s in e.get("senses", []):
            if sense_tags(s) & BLOCKED_TAGS:
                return True
    return False


def lemma_senses(e: dict) -> list[dict]:
    """Real definitions (not 'plural of …' / 'alternative form of …')."""
    good = []
    for s in e.get("senses", []):
        if s.get("form_of") or s.get("alt_of") or not s.get("glosses"):
            continue
        g = s["glosses"][-1].lower()
        if re.match(r"(plural|feminine|masculine|inflection|alternative|obsolete|archaic|misspelling) (form |spelling )?of\b", g):
            continue
        good.append(s)
    return good


def form_of_targets(e: dict) -> list[str]:
    out = []
    for s in e.get("senses", []):
        for t in (s.get("form_of") or []):
            if t.get("word"):
                out.append(t["word"].lower())
    return out


def clean_gloss(g: str) -> str:
    g = re.sub(r"\s*\([^)]*\)", "", g).strip()        # drop parenthetical notes
    g = g.split(";")[0].strip()
    g = re.sub(r"\s+", " ", g).rstrip(".")
    return g


STOPWORDS = {"to", "a", "an", "the", "of", "one", "be", "or", "and", "in", "on", "for", "with", "as", "at",
             "by", "from", "something", "someone", "oneself", "somebody", "etc", "used", "very", "some", "any"}


def keywords(gloss: str) -> list[str]:
    """Content words of a gloss: "a room, chamber" → ["room", "chamber"]."""
    return [w for w in re.findall(r"[a-z]+", gloss.lower()) if w not in STOPWORDS and len(w) > 2][:3]


def english_variants(w: str) -> set[str]:
    v = {w, w + "s", w + "es", w + "ed", w + "d", w + "ing"}
    if w.endswith("y"): v |= {w[:-1] + "ies", w[:-1] + "ied"}
    if w.endswith("e"): v |= {w[:-1] + "ing"}
    return v


def english_for(senses: list[dict]) -> str | None:
    preferred = [s for s in senses if not (sense_tags(s) & WEAK_TAGS)] or senses
    out: list[str] = []
    for s in preferred[:4]:
        g = clean_gloss(s["glosses"][-1])
        if not g or len(g) > 45 or g.lower() in (x.lower() for x in out):
            continue
        out.append(g)
        if len(out) == 2 or len(" / ".join(out)) > 40:
            break
    return " / ".join(out) if out else None


def noun_gender(e: dict) -> str | None:
    for h in e.get("head_templates", []) or []:
        exp = h.get("expansion", "")
        m = re.match(r"^\S+(?: \S+)*? (m or f|m|f|mf|m pl|f pl)\b", exp)
        if m:
            g = m.group(1)
            return "m./f." if g in ("m or f", "mf") else g.replace(" pl", "") + "."
    tags = set(e.get("tags", []))
    for s in e.get("senses", []):
        tags |= set(s.get("tags", []))
    if "masculine" in tags and "feminine" in tags: return "m./f."
    if "masculine" in tags: return "m."
    if "feminine" in tags: return "f."
    return None


CLITICS = ("me ", "te ", "se ", "nos ", "os ")


def find_form(e: dict, required: set[str], forbidden: set[str] = frozenset()) -> str | None:
    for f in e.get("forms", []) or []:
        tags = set(f.get("tags", []))
        form = f.get("form", "")
        if not form or form == "-" or not required <= tags or tags & forbidden:
            continue
        # One word, or a reflexive form like "me acuerdo".
        if " " not in form or (form.startswith(CLITICS) and form.count(" ") == 1):
            return form
    return None


HEAD_FORM = re.compile(
    r"\b(masculine plural|feminine plural|masculine singular|feminine singular|neuter|feminine|masculine|plural)"
    r"\s+([a-záéíóúüñ]+)", re.IGNORECASE)


def head_forms(e: dict) -> dict[str, str]:
    """Forms listed only in the headword line, e.g.
    "este (feminine esta, masculine plural estos, feminine plural estas, neuter esto)"."""
    out: dict[str, str] = {}
    for h in e.get("head_templates", []) or []:
        for m in HEAD_FORM.finditer(h.get("expansion", "")):
            out.setdefault(m.group(1).lower(), m.group(2))
    return out


def gendered_rows(e: dict, word: str) -> list[tuple[str, str]]:
    """masculine / feminine / plural (/ neuter) for adjectives, determiners, articles, pronouns, numbers."""
    h = head_forms(e)
    fem = (find_form(e, {"feminine", "singular"}) or find_form(e, {"feminine"}, {"plural"})
           or h.get("feminine singular") or h.get("feminine"))
    mpl = find_form(e, {"masculine", "plural"}) or h.get("masculine plural")
    fpl = find_form(e, {"feminine", "plural"}) or h.get("feminine plural")
    pl = find_form(e, {"plural"}, {"feminine", "masculine"}) or h.get("plural")
    neuter = find_form(e, {"neuter"}) or h.get("neuter")
    rows: list[tuple[str, str]] = []
    if fem and fem != word:
        rows = [("masculine", word), ("feminine", fem)]
        plurals = [x for x in dict.fromkeys((mpl, fpl)) if x] or ([pl] if pl else [])
        if plurals:
            rows.append(("plural", " / ".join(plurals)))
    elif mpl or pl:
        rows = [("m. & f.", word), ("plural", mpl or pl)]
    if neuter and neuter != word and rows:
        rows.append(("neuter", neuter))
    return rows


KEY_FORM_POS = {"verb", "noun", "adj", "det", "article", "pron", "num"}


def key_forms(e: dict, word: str) -> str | None:
    """One "label: value" per line; the app shows these as a small two-column table."""
    pos = e.get("pos")
    rows: list[tuple[str, str]] = []
    if pos == "verb":
        bad = {"subjunctive", "imperative", "voseo", "vos", "vos-form", "formal", "obsolete", "archaic", "dated"}
        yo = find_form(e, {"first-person", "singular", "present", "indicative"}, bad)
        tu = find_form(e, {"second-person", "singular", "present", "indicative"}, bad)
        el = find_form(e, {"third-person", "singular", "present", "indicative"}, bad)
        past = find_form(e, {"first-person", "singular", "preterite", "indicative"}, bad)
        if yo and tu and el:
            rows = [("yo", yo), ("tú", tu), ("él / ella", el)]
            if past:
                rows.append(("past (yo)", past))
    elif pos == "noun":
        h = head_forms(e)
        g = noun_gender(e)
        plural = find_form(e, {"plural"}, {"feminine"}) or h.get("plural")
        fem = find_form(e, {"feminine"}, {"plural"}) or h.get("feminine")        # amigo → amiga
        fem_pl = find_form(e, {"feminine", "plural"}) or h.get("feminine plural")
        if fem and fem != word:
            rows.append(("singular", f"el {word} / la {fem}"))
            if plural:
                rows.append(("plural", f"los {plural}" + (f" / las {fem_pl}" if fem_pl else "")))
        else:
            article, plural_article = {"m.": ("el", "los"), "f.": ("la", "las"),
                                       "m./f.": ("el / la", "los / las")}.get(g or "", ("", ""))
            if article:
                rows.append(("singular", f"{article} {word}"))
            if plural and plural != word:
                rows.append(("plural", f"{plural_article} {plural}".strip()))
    elif pos in ("adj", "det", "article", "pron", "num"):
        rows = gendered_rows(e, word)
    return "\n".join(f"{label}: {value}" for label, value in rows) or None


# ─────────────────────────────────────────────────────────────── Tatoeba

def load_tatoeba(args) -> list[tuple[str, str]]:
    """Returns (spanish, english) sentence pairs."""
    tdir = CACHE / "tatoeba"
    try:
        spa = download(TATOEBA_PER_LANGUAGE["spa"], tdir / "spa_sentences.tsv.bz2")
        eng = download(TATOEBA_PER_LANGUAGE["eng"], tdir / "eng_sentences.tsv.bz2")
        links = download(TATOEBA_PER_LANGUAGE["links"], tdir / "spa-eng_links.tsv.bz2")
        return pair_sentences(read_sentences(spa, "spa"), lambda: read_sentences(eng, "eng"), read_links(links))
    except Exception as err:  # per-language exports unavailable → full archives
        print(f"  per-language Tatoeba exports unavailable ({err}); using the full archives")
    sentences = download(TATOEBA_FULL["sentences"], tdir / "sentences.tar.bz2")
    links = download(TATOEBA_FULL["links"], tdir / "links.tar.bz2")
    spa, eng_ids_needed = {}, set()
    for sid, lang, text in tar_rows(sentences, 3):
        if lang == "spa":
            spa[sid] = text
    link_rows = [(a, b) for a, b in tar_rows(links, 2)]
    pairs_ids = defaultdict(list)
    for a, b in link_rows:
        if a in spa:
            pairs_ids[a].append(b); eng_ids_needed.add(b)
    eng = {sid: text for sid, lang, text in tar_rows(sentences, 3) if lang == "eng" and sid in eng_ids_needed}
    return [(spa[a], eng[b]) for a, bs in pairs_ids.items() for b in bs[:1] if b in eng]


def tar_rows(path: pathlib.Path, ncols: int):
    with tarfile.open(path, "r:bz2") as tar:
        for member in tar:
            if not member.isfile():
                continue
            f = io.TextIOWrapper(tar.extractfile(member), encoding="utf-8")
            for line in f:
                cols = line.rstrip("\n").split("\t")
                if len(cols) >= ncols:
                    yield tuple(cols[:ncols])


def read_sentences(path: pathlib.Path, lang: str) -> dict[str, str]:
    out = {}
    with open_text(path) as f:
        for line in f:
            cols = line.rstrip("\n").split("\t")
            if len(cols) >= 3 and cols[1] == lang:
                out[cols[0]] = cols[2]
    return out


def read_links(path: pathlib.Path) -> list[tuple[str, str]]:
    with open_text(path) as f:
        return [tuple(line.split()[:2]) for line in f if len(line.split()) >= 2]


def pair_sentences(spa: dict[str, str], eng_loader, links) -> list[tuple[str, str]]:
    eng = eng_loader()
    first = {}
    for a, b in links:
        if a in spa and b in eng and a not in first:
            first[a] = eng[b]
    return [(spa[a], e) for a, e in first.items()]


# ─────────────────────────────────────────────────────────────── build

def level_for(rank: int) -> str:
    for cutoff, name in LEVEL_CUTOFFS:
        if rank <= cutoff:
            return name
    return "fluent"


def build(args) -> list[dict]:
    CACHE.mkdir(parents=True, exist_ok=True)

    freq_path = pathlib.Path(args.freq_file) if args.freq_file else download(FREQ_URL, CACHE / "es_50k.txt")
    freq = load_frequency(freq_path)
    form_rank = {w: i + 1 for i, (w, _) in enumerate(freq)}
    print(f"Frequency list: {len(freq):,} word forms")

    # 1. Wiktionary entries for every frequent form (+ the lemmas those forms point to).
    subset = CACHE / "kaikki-es-subset.jsonl"
    if args.kaikki_file:
        sources = [(pathlib.Path(args.kaikki_file), args.kaikki_file.endswith(".gz"))]
    else:
        sources = []
        for url, raw in KAIKKI_URLS:
            try:
                sources = [(download(url, CACHE / url.rsplit("/", 1)[1]), raw)]
                break
            except Exception as err:
                print(f"  could not download {url}: {err}")
        if not sources:
            sys.exit("No Wiktionary data available — see the URLs at the top of this script.")
    src, raw = sources[0]

    if args.rebuild_subset and subset.exists():
        subset.unlink()
    if not subset.exists():
        kaikki_subset({w for w, _ in freq}, src, raw, subset)
    entries = load_entries(subset)
    missing = {t for w in entries for e in entries[w] for t in form_of_targets(e)} - set(entries)
    if missing:
        kaikki_subset(missing, src, raw, subset)
        entries = load_entries(subset)
    print(f"Wiktionary: {sum(len(v) for v in entries.values()):,} entries for {len(entries):,} headwords")

    # 2. Lemmatize the frequency list: credit each form's count to its dictionary headword.
    lemma_count: dict[str, int] = defaultdict(int)
    for w, count in freq:
        es = entries.get(w, [])
        if any(lemma_senses(e) and e.get("pos") in POS_LABELS for e in es):
            lemma_count[w] += count
        else:
            for t in dict.fromkeys(t for e in es for t in form_of_targets(e)):
                lemma_count[t] += count
                break
    ranked = sorted(lemma_count.items(), key=lambda kv: -kv[1])

    blocked = {w for w, es in entries.items() if is_blocked(es)}
    blocked_forms = set(blocked)
    for w, es in entries.items():
        if any(t in blocked for e in es for t in form_of_targets(e)):
            blocked_forms.add(w)

    # 3. Example sentences, indexed by word form (short sentences only).
    pairs = [] if args.no_tatoeba else load_tatoeba(args)
    print(f"Tatoeba: {len(pairs):,} Spanish–English sentence pairs")
    index: dict[str, list[int]] = defaultdict(list)
    scored = []
    for i, (es_text, en_text) in enumerate(pairs):
        toks = tokens(es_text)
        if not 3 <= len(toks) <= 10 or len(en_text) > 90 or blocked_forms & set(toks):
            continue
        difficulty = max(form_rank.get(t, 60_000) for t in toks)
        scored.append((difficulty + 40 * len(toks), es_text, en_text, set(re.findall(r"[a-z]+", en_text.lower()))))
        for t in set(toks):
            index[t].append(len(scored) - 1)

    # A word can have several meanings (cuarto = room / fourth / quarter). Each meaning gets its own
    # example: a sentence only counts for a meaning if its *English translation* uses that meaning
    # ("room"), so the example always matches. The meaning with the most real sentences comes first.

    def wiktionary_example(sense: dict) -> tuple[str, str] | None:
        for ex in sense.get("examples", []) or []:
            tr = ex.get("translation") or ex.get("english")
            if ex.get("text") and tr and len(ex["text"]) <= 90 and not (blocked_forms & set(tokens(ex["text"]))):
                return ex["text"], tr
        return None

    def spanish_forms(lemma: str, entry: dict) -> set[str]:
        return {lemma} | {f.get("form", "").lower() for f in entry.get("forms", []) or []
                          if f.get("form") and " " not in f["form"]}

    def candidate_meanings(lemma: str) -> list[dict]:
        out: list[dict] = []
        for e in entries.get(lemma, []):
            if e.get("pos") not in POS_LABELS:
                continue
            for sense in lemma_senses(e)[:5]:
                if sense_tags(sense) & (WEAK_TAGS | BLOCKED_TAGS):
                    continue
                gloss = clean_gloss(sense["glosses"][-1])
                kws = keywords(gloss) or re.findall(r"[a-z]+", gloss.lower())[:1]   # "the", "to be"
                if not gloss or len(gloss) > 40 or not kws:
                    continue
                if any(set(kws) & set(m["kws"]) for m in out):
                    continue                        # same idea worded differently
                out.append({"gloss": gloss, "kws": kws, "entry": e, "sense": sense})
        return out

    def support(lemma: str, meaning: dict) -> tuple[int, tuple[str, str] | None]:
        """How many sentence pairs use this meaning, and the easiest one."""
        variants = set().union(*(english_variants(k) for k in meaning["kws"][:1]))
        best, count = None, 0
        for form in spanish_forms(lemma, meaning["entry"]):
            for k in index.get(form, []):
                if not (scored[k][3] & variants):
                    continue
                count += 1
                cand = (scored[k][0] + (0 if form == lemma else 150), k)
                if best is None or cand < best:
                    best = cand
        return count, ((scored[best[1]][1], scored[best[1]][2]) if best else None)

    def pos_label(entry: dict) -> str:
        pos = POS_LABELS[entry["pos"]]
        if entry["pos"] == "noun" and (g := noun_gender(entry)):
            pos = f"noun ({g})"
        return pos

    # 4. Cards.
    cards, skipped = [], defaultdict(int)
    for rank, (lemma, _) in enumerate(ranked, 1):
        if len(cards) >= args.count:
            break
        if lemma in blocked:
            skipped["vulgar/offensive"] += 1; continue
        meanings = candidate_meanings(lemma)
        if not meanings:
            skipped["no usable definition"] += 1; continue

        for order, m in enumerate(meanings):
            m["count"], m["example"] = support(lemma, m)
            m["order"] = order
            if not m["example"]:
                m["example"] = wiktionary_example(m["sense"])
        # Most-used meaning first; Wiktionary's order breaks ties.
        meanings.sort(key=lambda m: (-m["count"], m["order"]))
        primary = meanings[0]
        if not primary["example"] and len(meanings) == 1:
            # Only one meaning, so any sentence with the word is safe to use.
            best = min(((scored[k][0], k) for f in spanish_forms(lemma, primary["entry"]) for k in index.get(f, [])),
                       default=None)
            if best:
                primary["example"] = (scored[best[1]][1], scored[best[1]][2])
        if not primary["example"]:
            skipped["no matching example sentence"] += 1; continue

        # Other meanings: real usage (≥3% as many sentences as the main meaning) or a dictionary example.
        others = [m for m in meanings[1:]
                  if m["example"] and (m["count"] >= max(1, 0.03 * primary["count"]) or m["count"] == 0)][:2]

        card = {
            "id": slug(lemma), "spanish": lemma, "english": primary["gloss"],
            "partOfSpeech": pos_label(primary["entry"]),
            "phonetic": respell(lemma), "example": primary["example"][0], "exampleTranslation": primary["example"][1],
            "level": level_for(rank), "kind": "phrase" if primary["entry"]["pos"] == "phrase" else "word",
            "source": "dictionary",
        }
        if forms := key_forms(primary["entry"], lemma):
            card["forms"] = forms
        if others:
            card["otherMeanings"] = []
            for m in others:
                om = {"english": m["gloss"], "partOfSpeech": pos_label(m["entry"]),
                      "example": m["example"][0], "exampleTranslation": m["example"][1]}
                if m["entry"] is not primary["entry"] and (f := key_forms(m["entry"], lemma)):
                    om["forms"] = f
                card["otherMeanings"].append(om)
        cards.append(card)

    # Sweep: which cards that *could* change form ended up without key forms?
    changeable = {"verb", "noun", "adjective", "determiner", "article", "pronoun", "number"}
    missing = [c for c in cards if not c.get("forms") and c["partOfSpeech"].split(" ")[0] in changeable]
    report = CACHE / "missing_key_forms.txt"
    report.write_text("\n".join(f'{c["spanish"]}\t{c["partOfSpeech"]}\t{c["english"]}' for c in missing) + "\n",
                      encoding="utf-8")
    by_pos = defaultdict(int)
    for c in missing:
        by_pos[c["partOfSpeech"].split(" ")[0]] += 1
    with_forms = sum(1 for c in cards if c.get("forms"))
    print(f"Key forms: {with_forms:,} of {len(cards):,} cards. Without (verbs/nouns/adjectives/etc. only): "
          + (", ".join(f"{v} {k}" for k, v in sorted(by_pos.items(), key=lambda kv: -kv[1])) or "none")
          + f"  → list in {report.relative_to(ROOT)}")
    print(f"Generated {len(cards):,} cards. Skipped: " + ", ".join(f"{v:,} {k}" for k, v in skipped.items()))
    return cards


def merge() -> None:
    curated = json.loads(CURATED.read_text(encoding="utf-8")) if CURATED.exists() else []
    generated = json.loads(GENERATED.read_text(encoding="utf-8")) if GENERATED.exists() else []
    sys.path.insert(0, str(TOOLS))
    from curated_forms import FORMS as CURATED_FORMS, MEANING_FORMS

    generated_forms = {g["spanish"].lower(): g["forms"] for g in generated if g.get("forms")}
    deck, ids = [], set()
    curated_words = {c["spanish"].lower() for c in curated}
    with_forms = 0
    for c in curated:
        # Key forms: hand-checked table first, then the dictionary's, if the word was imported.
        forms = CURATED_FORMS.get(c["spanish"]) or generated_forms.get(c["spanish"].lower())
        if forms:
            c = {**c, "forms": forms}; with_forms += 1
        if c.get("otherMeanings"):
            c = {**c, "otherMeanings": [
                {**m, "forms": MEANING_FORMS[(c["spanish"], i)]} if (c["spanish"], i) in MEANING_FORMS else m
                for i, m in enumerate(c["otherMeanings"])]}
        deck.append(c); ids.add(c["id"])
    added = 0
    for g in generated:
        if g["spanish"].lower() in curated_words:
            continue                       # the hand-written card wins
        base, n = g["id"], 2
        while g["id"] in ids:              # e.g. "como" vs "cómo" share a slug
            g = {**g, "id": f"{base}-{n}"}; n += 1
        deck.append(g); ids.add(g["id"]); added += 1
    DECK.write_text(json.dumps(deck, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    by_level = defaultdict(int)
    for c in deck:
        by_level[c["level"]] += 1
    print(f"Shared/words.json: {len(deck):,} cards ({len(curated)} curated, {with_forms} with key forms, "
          f"+ {added:,} from the dictionary) — "
          + ", ".join(f"{k} {v:,}" for k, v in by_level.items()))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--count", type=int, default=5000, help="how many dictionary cards to generate (default 5000)")
    ap.add_argument("--merge-only", action="store_true", help="only merge tools/curated.json + tools/generated.json")
    ap.add_argument("--no-tatoeba", action="store_true", help="use only Wiktionary usage examples")
    ap.add_argument("--rebuild-subset", action="store_true", help="re-scan the Wiktionary dump")
    ap.add_argument("--freq-file", help="use a local frequency list instead of downloading")
    ap.add_argument("--kaikki-file", help="use a local Wiktextract JSONL(.gz) instead of downloading")
    args = ap.parse_args()

    if not args.merge_only:
        cards = build(args)
        GENERATED.write_text(json.dumps(cards, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    merge()


if __name__ == "__main__":
    main()
