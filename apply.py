"""Phase 2: fetch metadata for curated picks, verify each image loads, write them into content/*.json."""
import json, pathlib, sys, time, urllib.request
from museums import get, met_object, UA
from picks import CARDS, EVENTS

ROOT = pathlib.Path(__file__).resolve().parents[2]
LICENSE = {"met": "Domaine public — CC0 (The Met Open Access)", "aic": "Domaine public — CC0 (Art Institute of Chicago)"}
MUSEUM = {"met": "The Metropolitan Museum of Art, New York", "aic": "Art Institute of Chicago"}
cache = {}

def meta(src, oid):
    if (src, oid) in cache: return cache[(src, oid)]
    if src == "met":
        m = met_object(oid)
    else:
        d = get(f"https://api.artic.edu/api/v1/artworks/{oid}?fields=id,title,artist_display,date_display,image_id,is_public_domain,credit_line")["data"]
        m = None if not (d["is_public_domain"] and d["image_id"]) else {
            "title": d["title"], "artist": d["artist_display"].splitlines()[0], "date": d["date_display"], "credit": d.get("credit_line") or "",
            "url": f"https://www.artic.edu/iiif/2/{d['image_id']}/full/843,/0/default.jpg", "page": f"https://www.artic.edu/artworks/{oid}"}
    if not m: raise SystemExit(f"{src}{oid} is not public domain or has no image")
    req = urllib.request.Request(m["url"], headers={"User-Agent": UA, "Range": "bytes=0-1023"})
    with urllib.request.urlopen(req, timeout=30) as r:
        if r.status not in (200, 206) or not r.headers.get("Content-Type", "").startswith("image/"):
            raise SystemExit(f"{src}{oid}: image did not load ({r.status} {r.headers.get('Content-Type')})")
    time.sleep(0.2)
    cache[(src, oid)] = m
    return m

def image(src, oid, fr, en):
    m = meta(src, oid)
    who = (m["artist"] or "").strip()
    credit = ", ".join(x for x in [who, m["title"], m["date"]] if x) + f" — {MUSEUM[src]}"
    if m.get("credit"): credit += f" ({m['credit']})"
    return {"url": m["url"], "license": LICENSE[src], "credit": credit, "sourcePage": m["page"], "altText": {"fr": fr, "en": en}}

for topic in ["art", "music", "history", "politics", "geopolitics"]:
    path = ROOT / "content/cards" / f"{topic}.json"
    cards = json.loads(path.read_text())
    for c in cards:
        if c["id"] in CARDS:
            imgs = [image(*p) for p in CARDS[c["id"]]]
            c["image"], c["gallery"] = imgs[0], imgs[1:]
            c.pop("imageSuggestion", None)
            print("card ", c["id"], len(imgs))
    path.write_text(json.dumps(cards, ensure_ascii=False, indent=2) + "\n")

path = ROOT / "content/events/events.json"
events = json.loads(path.read_text())
for e in events:
    e.pop("imageURL", None)
    if e["id"] in EVENTS:
        e["image"] = image(*EVENTS[e["id"]])
        print("event", e["id"])
path.write_text(json.dumps(events, ensure_ascii=False, indent=2) + "\n")
