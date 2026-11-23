from common import *

cities = [
 {"id": "paris", "name": L("Paris", "Paris"), "timeZoneID": "Europe/Paris", "latitude": 48.8566, "longitude": 2.3522},
 {"id": "frankfurt", "name": L("Francfort", "Frankfurt"), "timeZoneID": "Europe/Berlin", "latitude": 50.1109, "longitude": 8.6821},
 {"id": "munich", "name": L("Munich", "Munich"), "timeZoneID": "Europe/Berlin", "latitude": 48.1351, "longitude": 11.5820},
]

def V(id, name, city, address, lat, lon, site, note=None):
    v = {"id": id, "name": name, "cityID": city, "address": address, "latitude": lat, "longitude": lon, "website": site}
    if note: v["note"] = L(*note)
    return v

venues = [
 V("palais-garnier", "Palais Garnier", "paris", "Place de l'Opéra, 75009 Paris", 48.8720, 2.3316, "https://www.operadeparis.fr"),
 V("opera-bastille", "Opéra Bastille", "paris", "Place de la Bastille, 75012 Paris", 48.8522, 2.3700, "https://www.operadeparis.fr"),
 V("centre-pompidou", "Centre Pompidou", "paris", "Place Georges-Pompidou, 75004 Paris", 48.8606, 2.3522, "https://www.centrepompidou.fr",
   ("Bâtiment fermé pour travaux de rénovation (réouverture annoncée vers 2030) ; programmation hors les murs.",
    "Building closed for renovation (reopening announced for around 2030); programme held off-site.")),
 V("cite-sciences", "Cité des sciences et de l'industrie", "paris", "30 avenue Corentin-Cariou, 75019 Paris", 48.8956, 2.3880, "https://www.cite-sciences.fr"),
 V("oper-frankfurt", "Oper Frankfurt", "frankfurt", "Willy-Brandt-Platz 1, 60311 Frankfurt am Main", 50.1078, 8.6745, "https://oper-frankfurt.de"),
 V("staedel", "Städel Museum", "frankfurt", "Schaumainkai 63, 60596 Frankfurt am Main", 50.1031, 8.6741, "https://www.staedelmuseum.de"),
 V("senckenberg", "Senckenberg Naturmuseum", "frankfurt", "Senckenberganlage 25, 60325 Frankfurt am Main", 50.1175, 8.6518, "https://museumfrankfurt.senckenberg.de"),
 V("bayerische-staatsoper", "Bayerische Staatsoper — Nationaltheater", "munich", "Max-Joseph-Platz 2, 80539 München", 48.1394, 11.5786, "https://www.staatsoper.de"),
 V("alte-pinakothek", "Alte Pinakothek", "munich", "Barer Straße 27, 80333 München", 48.1482, 11.5700, "https://www.pinakothek.de"),
 V("pinakothek-moderne", "Pinakothek der Moderne", "munich", "Barer Straße 40, 80333 München", 48.1473, 11.5721, "https://www.pinakothek.de"),
 V("deutsches-museum", "Deutsches Museum", "munich", "Museumsinsel 1, 80538 München", 48.1299, 11.5834, "https://www.deutsches-museum.de"),
]
venue_by_id = {v["id"]: v for v in venues}
CITY_TZ = {c["id"]: c["timeZoneID"] for c in cities}
SOURCE = {"palais-garnier": "Opéra national de Paris", "opera-bastille": "Opéra national de Paris", "cite-sciences": "Universcience",
          "oper-frankfurt": "Oper Frankfurt", "staedel": "Städel Museum", "senckenberg": "Senckenberg Gesellschaft für Naturforschung",
          "bayerische-staatsoper": "Bayerische Staatsoper", "alte-pinakothek": "Bayerische Staatsgemäldesammlungen",
          "pinakothek-moderne": "Bayerische Staatsgemäldesammlungen", "deutsches-museum": "Deutsches Museum"}

def EV(id, title, category, venue, start, end=None, price=(None, None), free=False, status="scheduled", desc=None, status_note=None):
    v = venue_by_id[venue]
    e = {"id": id, "title": title, "category": category, "cityID": v["cityID"], "venueID": venue,
         "start": start, "timeZoneID": CITY_TZ[v["cityID"]],
         "price": {"minEUR": 0 if free else price[0], "maxEUR": 0 if free else price[1], "isFree": free},
         "officialURL": v["website"], "sourceName": SOURCE[venue], "lastChecked": "2026-11-22T08:00:00Z",
         "status": status, "editorialStatus": "in_review", "isSample": True}
    if end: e["end"] = end
    e["description"] = L(*(desc or ("Événement d'exemple pour tester l'Agenda. À remplacer par la programmation officielle du lieu.",
                                     "Sample event for testing the Agenda. To be replaced with the venue's official programme.")))
    if status_note: e["statusNote"] = L(*status_note)
    return e

events = [
 EV("evt-paris-001", "[Exemple] Soirée de ballet", "opera_ballet", "palais-garnier", "2026-11-28T19:30:00+01:00", "2026-11-28T22:00:00+01:00", (15, 150)),
 EV("evt-paris-002", "[Exemple] La traviata", "opera_ballet", "opera-bastille", "2026-12-03T19:30:00+01:00", "2026-12-03T22:30:00+01:00", (15, 230)),
 EV("evt-paris-003", "[Exemple] Concert de la Saint-Sylvestre", "classical", "opera-bastille", "2026-12-31T23:30:00+01:00", "2027-01-01T00:45:00+01:00", (30, 120),
    desc=("Cas de test : début à 23 h 30, heure de Paris. La date affichée doit rester le 31 décembre, quel que soit le fuseau de l'appareil.",
          "Test case: starts at 23:30 Paris time. The displayed date must stay 31 December whatever the device time zone.")),
 EV("evt-paris-004", "[Exemple] Conférence : à la recherche des exoplanètes", "science", "cite-sciences", "2026-11-26T18:30:00+01:00", "2026-11-26T20:00:00+01:00", free=True),
 EV("evt-paris-005", "[Exemple] Exposition temporaire", "exhibitions", "cite-sciences", "2026-10-15T10:00:00+02:00", "2027-08-29T18:00:00+02:00", (13, 15)),
 EV("evt-paris-006", "[Exemple] Récital de piano", "classical", "palais-garnier", "2026-12-05T20:00:00+01:00", None, (20, 90), status="cancelled",
    status_note=("Représentation annulée par le lieu. Les billets sont remboursés via le site officiel.", "Performance cancelled by the venue. Tickets are refunded via the official site.")),
 EV("evt-ffm-001", "[Exemple] Die Zauberflöte", "opera_ballet", "oper-frankfurt", "2026-11-29T18:00:00+01:00", "2026-11-29T21:00:00+01:00", (15, 125)),
 EV("evt-ffm-002", "[Exemple] Ausstellung: Meister der Renaissance", "exhibitions", "staedel", "2026-10-01T10:00:00+02:00", "2027-02-01T18:00:00+01:00", (16, 18)),
 EV("evt-ffm-003", "[Exemple] Vortrag: Dinosaurier und Klima", "science", "senckenberg", "2026-12-02T19:00:00+01:00", "2026-12-02T20:30:00+01:00", free=True),
 EV("evt-ffm-004", "[Exemple] Liederabend", "classical", "oper-frankfurt", "2026-12-12T19:30:00+01:00", None, (20, 60), status="sold_out"),
 EV("evt-muc-001", "[Exemple] Tristan und Isolde", "opera_ballet", "bayerische-staatsoper", "2026-11-27T17:00:00+01:00", "2026-11-27T22:15:00+01:00", (13, 250)),
 EV("evt-muc-002", "[Exemple] Dürer und seine Zeit", "exhibitions", "alte-pinakothek", "2026-09-15T10:00:00+02:00", "2027-01-10T18:00:00+01:00", (9, 9)),
 EV("evt-muc-003", "[Exemple] Wissenschaft für alle: Quantencomputer", "science", "deutsches-museum", "2026-12-04T18:30:00+01:00", "2026-12-04T20:00:00+01:00", free=True),
 EV("evt-muc-004", "[Exemple] Der Nussknacker", "opera_ballet", "bayerische-staatsoper", "2026-12-20T19:00:00+01:00", "2026-12-20T21:30:00+01:00", (11, 140)),
 EV("evt-muc-005", "[Exemple] Design im Dialog", "exhibitions", "pinakothek-moderne", "2026-11-01T10:00:00+01:00", "2027-03-01T18:00:00+01:00", (10, 10)),
]

write("events/cities.json", cities)
write("events/venues.json", venues)
write("events/events.json", events)
