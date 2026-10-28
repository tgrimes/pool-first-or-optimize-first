"""Build references.bib from Zotero's own BibTeX export, through its local API.

Usage:
  python3 -I build-bib.py citations.csv references.bib
          [--api http://127.0.0.1:23119] [--fixes zotero-fixes.md] [--seed references-seed.bib]
          [--parent-bib path/to/parent.bib] [--qmd manuscript.qmd] [--check]

For every row of citations.csv with a Zotero item key and usable = yes, the script fetches
  <api>/api/users/0/items/<item key>?format=bibtex
keeps only the fields a reference needs (author, editor, title, journal, booktitle, publisher and
address for books, series, edition, institution, type, year, volume, number, pages, doi, note), drops
abstracts, file paths, access dates, keywords, URLs, and an article's publisher, and replaces Zotero's
key with the row's key. Nothing else is changed in transit.

Faults in a record are the user's to fix in Zotero, not the script's to patch. They are written to
the fixes file with the item, the field, and the value to enter: a missing DOI (the checklist's
identifier is offered), a journal name in lower case, an author list of exactly ten (the Google
Scholar import cap), a pages field that holds a date or repeats one page as a range, an author
particle stored with the given names, and, when a parent bib is given, a title or author count that
differs from it. Rerun after the records are fixed; the fixes file should then
be empty.

With --qmd, only the keys cited in the manuscript (and its {{< include >}} files) are written, so the
checklist can keep candidate sources that the draft does not cite.

Zotero's local API needs "Allow other applications on this computer to communicate with Zotero"
turned on in Zotero's Advanced settings.
"""
import csv
import os
import re
import subprocess
import sys
import urllib.request
from datetime import date

args = sys.argv[1:]
if len(args) < 2:
    sys.exit(__doc__)
cit_path, out_path = args[0], args[1]
def opt(flag, default=None):
    if flag in args:
        i = args.index(flag)
        return True if flag == "--check" else args[i + 1]
    return default
api = opt("--api", "http://127.0.0.1:23119").rstrip("/")
fixes_path = opt("--fixes", os.path.join(os.path.dirname(out_path) or ".", "zotero-fixes.md"))
seed_path = opt("--seed", os.path.join(os.path.dirname(os.path.abspath(__file__)), "references-seed.bib"))
parent_path = opt("--parent-bib")
qmd_path = opt("--qmd")
do_check = bool(opt("--check", False))

KEEP = ["author", "editor", "title", "journal", "booktitle", "publisher", "address", "series", "edition",
        "institution", "type", "year", "volume", "number", "pages", "doi", "note"]

def fetch(item_key):
    url = f"{api}/api/users/0/items/{item_key}?format=bibtex"
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            return r.read().decode("utf-8")
    except Exception as e:  # connection refused, 404, timeout
        return None

def parse_entry(text):
    m = re.search(r"@(\w+)\{([^,]+),(.*)\}\s*$", text.strip(), flags=re.S)
    if not m:
        return None
    typ, zkey, body = m.groups()
    fields = {}
    for fm in re.finditer(r"^\s*(\w+)\s*=\s*(\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\}|\w+),?\s*$", body, flags=re.M):
        v = fm.group(2)
        fields[fm.group(1).lower()] = v[1:-1] if v.startswith("{") else v
    return typ.lower(), zkey, fields

def parse_bib(path):
    # Brace-balanced parser: handles one-line entries and nested braces (the regex version read a file of
    # one-line entries as a single entry). Fixed in the SS1 copy, 2026-10-27.
    out = {}
    text = open(path, encoding="utf-8").read()
    for m in re.finditer(r"@(\w+)\s*\{\s*([^,\s]+)\s*,", text):
        i, depth = m.end(), 1
        while i < len(text) and depth:
            depth += {"{": 1, "}": -1}.get(text[i], 0); i += 1
        body = text[m.end():i - 1]
        f, j = {}, 0
        for fm in re.finditer(r"(\w+)\s*=\s*", body):
            if fm.start() < j:
                continue
            k = fm.end()
            if k < len(body) and body[k] == "{":
                d, k2 = 1, k + 1
                while k2 < len(body) and d:
                    d += {"{": 1, "}": -1}.get(body[k2], 0); k2 += 1
                f[fm.group(1).lower()] = body[k + 1:k2 - 1]; j = k2
            else:
                v = re.match(r"[^,}]*", body[k:]).group(0).strip().strip('"'); f[fm.group(1).lower()] = v; j = k + len(v)
        out[m.group(2).strip()] = (m.group(1).lower(), f)
    return out

norm = lambda s: re.sub(r"[{}]", "", s or "").replace("–", "-").replace("—", "-").replace("--", "-").strip().lower()
parent = parse_bib(parent_path) if parent_path else {}
seed = parse_bib(seed_path) if seed_path and os.path.exists(seed_path) else {}

def cited_keys(qmd):
    # @key, [@key], [-@key] in the qmd and in the files it includes; the key stops at the first
    # character pandoc would not accept
    text = open(qmd, encoding="utf-8").read()
    for inc in re.findall(r"\{\{<\s*include\s+([^\s>]+)\s*>\}\}", text):
        ip = os.path.join(os.path.dirname(os.path.abspath(qmd)), inc)
        if os.path.exists(ip):
            text += "\n" + open(ip, encoding="utf-8").read()
    return set(re.findall(r"(?<![\w@.])-?@([A-Za-z0-9_][\w:.#$%&+?<>~/-]*[\w])", text))

cited = cited_keys(qmd_path) if qmd_path else None
rows = list(csv.DictReader(open(cit_path, encoding="utf-8")))
entries, fixes, skipped, failed = [], [], [], []
for r in rows:
    key, zkey = r["key"].strip(), (r.get("zotero_item") or "").strip()
    usable = (r.get("usable") or "").strip().lower() == "yes"
    if cited is not None and key not in cited:
        skipped.append((key, "not cited in the manuscript")); continue
    if not zkey or not usable:
        if key in seed and usable:
            typ, f = seed[key]; entries.append((key, typ, f)); continue
        skipped.append((key, "no Zotero item" if not zkey else "not usable")); continue
    text = fetch(zkey)
    if text is None:
        failed.append((key, zkey)); continue
    parsed = parse_entry(text)
    if not parsed:
        failed.append((key, zkey)); continue
    typ, _, f = parsed
    kept = {k: f[k] for k in KEEP if k in f and f[k].strip()}
    if typ == "article":
        kept.pop("publisher", None); kept.pop("address", None)
    # faults, reported for Zotero and not patched
    ident = (r.get("identifier") or "").strip()
    if "doi" not in kept and ident and ident.lower() != "none":
        fixes.append((key, zkey, "DOI", f"missing in the record; enter: {ident}"))
    j = kept.get("journal", "")
    if j:
        wordsj = [w for w in re.split(r"\s+", re.sub(r"[{}]", "", j)) if w and w.lower() not in ("of", "the", "and", "in", "for", "on", "&")]
        if len(wordsj) > 1 and sum(1 for w in wordsj if w[0].isupper()) < len(wordsj) / 2:
            fixes.append((key, zkey, "journal", f"lower case from the import: {j!r}"))
    na = len([a for a in kept.get("author", "").split(" and ") if a.strip()])
    if na == 10:
        fixes.append((key, zkey, "author", "exactly ten authors: the Google Scholar import stops at ten, so check the paper's list"))
    # a date: a year followed by a month (2021--09, 2026.02.27...); a page range such as 2074--2102 is not one
    if re.search(r"^\s*(19|20)\d\d(-{1,2}|\.)(0[1-9]|1[0-2])(?![0-9])", kept.get("pages", "")):
        fixes.append((key, zkey, "pages", f"holds a date, not pages: {kept['pages']!r}"))
    # a range whose start and end are the same page (e47--e47) renders as a range
    mp = re.match(r"^\s*([A-Za-z]*\d+)\s*-{1,2}\s*\1\s*$", kept.get("pages", ""))
    if mp:
        fixes.append((key, zkey, "pages", f"start and end are the same page: {kept['pages']!r}; enter {mp.group(1)!r}"))
    # a closing quote glued to the next word in a title ("‘differential expression’to")
    if re.search(r"[’”'\"][A-Za-z]", re.sub(r"\{[^{}]*\}", "", kept.get("title", ""))) and re.search(r"[’”][A-Za-z]", kept.get("title", "")):
        fixes.append((key, zkey, "title", f"a closing quote runs into the next word: {re.sub(r'[{}]', '', kept['title'])!r}"))
    # a particle stored with the given names ("Fuente, Alberto de la") renders as "Fuente A de la"
    for au in kept.get("author", "").split(" and "):
        if "," in au and re.search(r"(^|\s)(de|de la|del|della|van|van der|van den|von|der|di|da|du|le|la)\s*$", au.split(",", 1)[1].strip()):
            fixes.append((key, zkey, "author", f"particle stored with the given names: {au.strip()!r}; move it to the family name"))
    if key in parent:
        ptyp, pf = parent[key]
        if norm(pf.get("title")) != norm(kept.get("title")):
            fixes.append((key, zkey, "title", f"differs from the parent bib: record {re.sub(r'[{}]', '', kept.get('title', ''))!r}; parent {re.sub(r'[{}]', '', pf.get('title', ''))!r}"))
        pa = len([a for a in pf.get("author", "").split(" and ") if a.strip()])
        if pa > na:
            fixes.append((key, zkey, "author", f"record lists {na} authors; the parent bib has {pa}"))
    entries.append((key, typ, kept))

# ---- write the bib -------------------------------------------------------------------------
entries.sort(key=lambda e: e[0].lower())
lines = [f"% references.bib built {date.today()} by build-bib.py from Zotero's local API ({api}).",
         "% Fields are Zotero's own export with abstracts, files, access dates, keywords, URLs, and an article's",
         "% publisher dropped and keys remapped through citations.csv; nothing else is changed. Record faults are",
         f"% listed in {os.path.basename(fixes_path)} for fixing in Zotero.", ""]
for key, typ, f in entries:
    lines.append(f"@{typ}{{{key},")
    for k in KEEP:
        if k in f:
            lines.append(f"  {k} = {{{f[k]}}},")
    lines[-1] = lines[-1].rstrip(",")
    lines.append("}\n")
open(out_path, "w", encoding="utf-8").write("\n".join(lines))

# ---- write the fixes -----------------------------------------------------------------------
fx = [f"# Zotero record fixes ({date.today()})", "",
      "Each line is a change to make in the Zotero record, so that the export needs no correction. Rerun build-bib.py after fixing; this file is rewritten each time and should end up empty.", "",
      "| Key | Zotero item | Field | What to change |", "|------------------|------------|----------|------------------------------------------------------------------|"]
for key, zkey, fld, what in fixes:
    fx.append(f"| `{key}` | {zkey} | {fld} | {what} |")
if not fixes:
    fx.append("| | | | none |")
open(fixes_path, "w", encoding="utf-8").write("\n".join(fx) + "\n")

print(f"wrote {len(entries)} entries to {out_path}; {len(fixes)} record faults in {fixes_path}")
for key, why in skipped:
    print(f"  skipped {key}: {why}")
for key, zkey in failed:
    print(f"  FAILED {key} ({zkey}): no BibTeX from {api}; is Zotero open with the local API allowed?")

# ---- optional citeproc check ----------------------------------------------------------------
if do_check and entries:
    test_md = os.path.join(os.path.dirname(os.path.abspath(out_path)), ".bib-check.md")
    open(test_md, "w", encoding="utf-8").write("---\nbibliography: " + os.path.basename(out_path) + "\n---\n\n" +
                                              " ".join(f"[@{k}]" for k, _, _ in entries) + "\n\n# References\n")
    res = subprocess.run(["quarto", "pandoc", test_md, "--citeproc", "-t", "plain"], capture_output=True, text=True,
                         cwd=os.path.dirname(os.path.abspath(out_path)))
    os.remove(test_md)
    warn = [l for l in (res.stderr or "").splitlines() if "WARNING" in l or "ERROR" in l]
    print("citeproc: " + ("no warnings" if not warn and res.returncode == 0 else "\n  " + "\n  ".join(warn or [res.stderr.strip()])))
sys.exit(1 if failed else 0)
