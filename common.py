"""Helpers for writing seed content compactly. Output goes to content/*.json, which
the editor (admin/) then edits directly. These scripts are only for the initial seed."""
import json, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent

def L(fr, en):
    return {"fr": fr, "en": en}

def S(title, publisher=None, url=None):
    d = {"title": title}
    if publisher: d["publisher"] = publisher
    if url: d["url"] = url
    return d

def quiz(q, options, answer, explanation):
    return {"question": L(*q), "options": [L(*o) for o in options], "answerIndex": answer, "explanation": L(*explanation)}

def card(id, topic, title, body, takeaway, q, sources, image_hint=None, kind="standard", timeline=None, facts_as_of=None, tags=()):
    c = {
        "id": id, "topic": topic, "kind": kind,
        "title": L(*title), "body": L(*body), "takeaway": L(*takeaway),
        "quiz": q, "tags": list(tags),
        "editorial": {"status": "in_review", "sources": sources, "lastReviewed": None, "reviewer": None},
    }
    if image_hint: c["imageSuggestion"] = image_hint
    if timeline: c["timeline"] = [{"date": d, "label": L(fr, en)} for d, fr, en in timeline]
    if facts_as_of: c["factsAsOf"] = facts_as_of
    return c

def write(path, data):
    p = OUT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("wrote", p.relative_to(OUT.parent), len(data) if isinstance(data, list) else "")
