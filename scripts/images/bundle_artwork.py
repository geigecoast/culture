#!/usr/bin/env python3
"""Downloads every image referenced in content/ into App/Resources/Artwork, resized to 1000 px.

The app loads these bundled copies first (offline, and immune to museum servers blocking traffic),
falling back to the network only for images added after the build. File name = sha256(url).jpg,
matching ImageCache.fileName(for:). Run after adding images in the editor, then commit the files.
"""
import hashlib, io, json, pathlib, sys, time, urllib.request
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
UA = {"User-Agent": "CultureContentCuration/0.1 (non-commercial content curation script)"}
OUT = ROOT / "App/Resources/Artwork"

def urls():
    found = set()
    for t in ["art", "music", "history", "politics", "geopolitics", "books", "philosophy"]:
        for c in json.loads((ROOT / f"content/cards/{t}.json").read_text()):
            for img in [c.get("image")] + c.get("gallery", []):
                if img: found.add(img["url"])
    for e in json.loads((ROOT / "content/events/events.json").read_text()):
        if e.get("image"): found.add(e["image"]["url"])
    return found

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    wanted = {hashlib.sha256(u.encode()).hexdigest() + ".jpg": u for u in urls()}
    for name, url in sorted(wanted.items()):
        path = OUT / name
        if path.exists():
            continue
        data = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
        image = Image.open(io.BytesIO(data)).convert("RGB")
        image.thumbnail((1000, 1000))
        image.save(path, "JPEG", quality=80, optimize=True, progressive=True)
        print("added", name, url)
        time.sleep(0.2)
    for stale in OUT.glob("*.jpg"):
        if stale.name not in wanted:
            stale.unlink(); print("removed", stale.name)
    size = sum(p.stat().st_size for p in OUT.glob("*.jpg"))
    print(f"{len(wanted)} images, {size / 1e6:.1f} MB")

if __name__ == "__main__":
    sys.exit(main())
