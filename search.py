"""Phase 1: list candidates per card for manual curation. Writes candidates.json."""
import json, sys, time
from museums import aic_search, met_search

QUERIES = {
 "art-001": [("aic", "Monet"), ("aic", "Pissarro"), ("aic", "Renoir")],
 "art-002": [("met", "Caravaggio"), ("met", "Georges de La Tour")],
 "art-003": [("met", "Leonardo da Vinci"), ("aic", "Leonardo da Vinci")],
 "art-004": [("met", "Juan Gris"), ("aic", "Gris cubism"), ("met", "Cubism Gris")],
 "art-005": [("met", "Saint-Denis stained glass"), ("met", "Gothic stained glass")],
 "art-006": [("aic", "Kandinsky"), ("aic", "Paul Klee"), ("met", "Bauhaus")],
 "art-007": [("met", "Albrecht Dürer"), ("aic", "Albrecht Dürer")],
 "art-008": [("met", "Rodin Thinker"), ("met", "Rodin")],
 "mus-001": [("met", "harpsichord"), ("met", "organ")],
 "mus-002": [("met", "Cristofori piano"), ("met", "fortepiano")],
 "mus-003": [("met", "Beethoven"), ("aic", "Beethoven")],
 "mus-004": [("met", "Stradivari violin"), ("met", "viola da gamba")],
 "mus-005": [("met", "opera stage"), ("aic", "opera Degas"), ("met", "Orpheus")],
 "mus-006": [("met", "saxophone"), ("met", "trumpet"), ("aic", "jazz")],
 "mus-007": [("aic", "faun"), ("met", "faun"), ("met", "flute")],
 "mus-008": [("met", "Wagner"), ("met", "Tristan Isolde"), ("aic", "Wagner")],
 "his-001": [("met", "Bastille 1789"), ("met", "French Revolution")],
 "his-002": [("met", "Callot Miseries of War"), ("met", "Thirty Years War")],
 "his-003": [("met", "Brandenburg Gate"), ("aic", "Berlin")],
 "his-004": [("met", "Piranesi Campidoglio"), ("met", "Piranesi Capitol")],
 "his-005": [("met", "Henri IV"), ("met", "Huguenot")],
 "his-006": [("met", "Congress of Vienna"), ("met", "Talleyrand"), ("met", "Metternich")],
 "his-007": [("met", "World War poster 1917"), ("aic", "World War I poster")],
 "his-008": [("met", "Nuremberg Chronicle"), ("met", "printing press"), ("met", "Gutenberg")],
 "pol-001": [("met", "Palais Bourbon"), ("met", "Chambre des députés")],
 "pol-002": [("met", "Palais-Royal"), ("met", "Palais Royal Paris")],
 "pol-003": [("met", "Europa and the bull"), ("aic", "Europa bull")],
 "pol-004": [("met", "Frankfurt"), ("met", "Reichstag")],
 "pol-005": [("met", "Montesquieu"), ("aic", "Montesquieu")],
 "pol-006": [("met", "Marianne"), ("met", "Liberty Republic France")],
 "pol-007": [("met", "Capitol Washington"), ("aic", "Capitol Washington")],
 "pol-008": [("met", "election"), ("aic", "election")],
 "geo-001": [("met", "map Atlantic"), ("met", "Washington 1949")],
 "geo-002": [("met", "Persian Gulf"), ("met", "Hormuz")],
 "geo-003": [("met", "map of Europe"), ("aic", "map Europe")],
 "geo-004": [("met", "Arctic"), ("aic", "iceberg"), ("met", "icebergs")],
 "geo-005": [("met", "Suez Canal"), ("met", "Suez")],
 "geo-006": [("met", "globe"), ("met", "celestial globe")],
 "geo-007": [("met", "junk ship China"), ("met", "Chinese junk")],
 "geo-008": [("met", "mineral"), ("aic", "mine")],
}

ids = sys.argv[1:] or list(QUERIES)
import os
out = json.load(open("candidates.json")) if os.path.exists("candidates.json") else {}
for cid in ids:
    cands = []
    for src, q in QUERIES[cid]:
        try:
            cands += (aic_search if src == "aic" else met_search)(q, 6)
        except Exception as e:
            print("  !", cid, q, e, file=sys.stderr)
        time.sleep(0.3)
    out[cid] = cands
    json.dump(out, open("candidates.json", "w"), ensure_ascii=False, indent=1)
    print(f"\n## {cid}")
    for i, c in enumerate(cands):
        print(f"  {i:2d} [{c['src']} {c['id']}] {c['title'][:70]} — {c['artist'][:40]} {c['date']}")
json.dump(out, open("candidates.json", "w"), ensure_ascii=False, indent=1)
