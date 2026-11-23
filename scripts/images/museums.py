"""Tiny clients for open-access museum APIs (CC0 / public-domain images only)."""
import json, time, urllib.request, urllib.parse

UA = "CultureContentCuration/0.1 (non-commercial content curation script)"

def get(url):
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "AIC-User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception as e:
            if attempt == 2: raise
            time.sleep(2 * (attempt + 1))

def aic_search(q, limit=8):
    fields = "id,title,artist_display,date_display,image_id,is_public_domain,credit_line,thumbnail"
    url = "https://api.artic.edu/api/v1/artworks/search?" + urllib.parse.urlencode(
        {"q": q, "limit": limit, "fields": fields, "query[term][is_public_domain]": "true"})
    out = []
    for d in get(url)["data"]:
        if d.get("is_public_domain") and d.get("image_id"):
            out.append({"src": "aic", "id": d["id"], "title": d["title"], "artist": d.get("artist_display") or "",
                        "date": d.get("date_display") or "", "credit": d.get("credit_line") or "",
                        "url": f"https://www.artic.edu/iiif/2/{d['image_id']}/full/843,/0/default.jpg",
                        "page": f"https://www.artic.edu/artworks/{d['id']}",
                        "alt": (d.get("thumbnail") or {}).get("alt_text") or ""})
    return out

def met_object(oid):
    d = get(f"https://collectionapi.metmuseum.org/public/collection/v1/objects/{oid}")
    if not (d.get("isPublicDomain") and d.get("primaryImageSmall")): return None
    return {"src": "met", "id": oid, "title": d["title"], "artist": d.get("artistDisplayName") or d.get("culture") or "",
            "date": d.get("objectDate") or "", "credit": d.get("creditLine") or "",
            "url": d["primaryImageSmall"], "page": d.get("objectURL") or f"https://www.metmuseum.org/art/collection/search/{oid}", "alt": ""}

def met_search(q, limit=8):
    url = "https://collectionapi.metmuseum.org/public/collection/v1.1/search?" + urllib.parse.urlencode({"q": q, "hasImages": "true", "limit": limit})
    ids = get(url).get("objectIDs") or []
    out = []
    for oid in ids[:limit]:
        time.sleep(0.15)
        try:
            o = met_object(oid)
            if o: out.append(o)
        except Exception:
            pass
    return out
