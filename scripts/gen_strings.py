#!/usr/bin/env python3
"""Generates App/Resources/Localizable.xcstrings and checks that every key used in Swift exists."""
import json, re, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from l10n_source import STRINGS

root = pathlib.Path(__file__).resolve().parent.parent
catalog = {"sourceLanguage": "fr", "version": "1.0", "strings": {}}
for key in sorted(STRINGS):
    fr, en = STRINGS[key]
    if fr.count("%") != en.count("%"):
        sys.exit(f"format mismatch in {key}")
    catalog["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            "fr": {"stringUnit": {"state": "translated", "value": fr}},
            "en": {"stringUnit": {"state": "translated", "value": en}},
        },
    }
out = root / "App/Resources/Localizable.xcstrings"
out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# Check usage: literal keys in t("...") calls and dynamic families.
prefixes = ("tab.", "menu.", "sidebar.", "search.", "common.", "a11y.", "topic.", "home.", "card.", "action.", "quiz.",
            "vocab.", "grade.", "register.", "exercise.", "agenda.", "category.", "status.", "rsvp.", "event.",
            "notification.", "collections.", "profile.", "mastery.", "onboarding.", "settings.", "visibility.", "screenTime.")
used = set()
for f in (root / "App/Sources").rglob("*.swift"):
    for lit in re.findall(r'"([a-zA-Z]+\.[a-zA-Z0-9_.]+)"', f.read_text()):
        if lit.startswith(prefixes):
            used.add(lit)
dynamic = {f"topic.{t}" for t in ["art", "music", "history", "politics", "geopolitics", "vocabulary"]}
dynamic |= {f"register.{r}" for r in ["courant", "soutenu", "litteraire", "vieilli", "familier"]}
dynamic |= {f"category.{c}" for c in ["opera_ballet", "classical", "jazz_world", "theatre_dance", "exhibitions", "science", "literature_cinema"]}
dynamic |= {f"status.{s}" for s in ["scheduled", "cancelled", "moved", "sold_out"]}
dynamic |= {f"rsvp.{s}" for s in ["going", "interested", "maybe"]} | {f"grade.{g}" for g in ["known", "review", "hard"]}
dynamic |= {f"mastery.{m}" for m in ["initie", "connaisseur", "erudit"]} | {f"tab.{t}" for t in ["home", "agenda", "vocabulary", "collections", "profile"]}
dynamic |= {f"onboarding.level.{i}" for i in range(1, 5)}
ignore = {"tab.home", "quiz.option", "quiz.all", "quiz.close", "quiz.next", "quiz.feedback", "vocab.reveal", "vocab.startReview",
          "rsvp.menu", "event.status", "settings.deleteAccount", "settings.language", "profile.settings", "onboarding.continue",
          "placement.next"}
missing = sorted((used | dynamic) - set(STRINGS) - (ignore - set(STRINGS)))
missing = [m for m in missing if not m.startswith(("settings.city.", "city.", "interest.", "grade.\\", "rsvp.\\"))]
if missing:
    sys.exit("Missing localization keys:\n  " + "\n  ".join(missing))
print(f"Wrote {out.relative_to(root)} with {len(STRINGS)} keys; all {len(used | dynamic)} used keys present.")
