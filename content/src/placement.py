from common import *

def P(id, topic, q, opts, ans, exp):
    return {"id": id, "topic": topic, "quiz": quiz(q, opts, ans, exp)}

placement = [
 P("pl-01", "art", ("Qui a peint La Joconde ?", "Who painted the Mona Lisa?"), [("Raphaël", "Raphael"), ("Léonard de Vinci", "Leonardo da Vinci"), ("Titien", "Titian"), ("Botticelli", "Botticelli")], 1, ("Vers 1503–1519.", "Around 1503–1519.")),
 P("pl-02", "art", ("Quel mouvement associe-t-on à Picasso et Braque vers 1908 ?", "Which movement is linked to Picasso and Braque around 1908?"), [("Fauvisme", "Fauvism"), ("Cubisme", "Cubism"), ("Surréalisme", "Surrealism"), ("Dadaïsme", "Dada")], 1, ("Le cubisme décompose les formes en facettes.", "Cubism breaks forms into facets.")),
 P("pl-03", "music", ("Quelle forme repose sur exposition, développement et réexposition ?", "Which form is based on exposition, development and recapitulation?"), [("La fugue", "Fugue"), ("Le rondo", "Rondo"), ("La forme sonate", "Sonata form"), ("Le canon", "Canon")], 2, ("C'est la forme du premier mouvement classique.", "It shapes the Classical first movement.")),
 P("pl-04", "music", ("Quel compositeur a écrit Le Clavier bien tempéré ?", "Who wrote The Well-Tempered Clavier?"), [("Haendel", "Handel"), ("Vivaldi", "Vivaldi"), ("J.-S. Bach", "J. S. Bach"), ("Mozart", "Mozart")], 2, ("Deux livres, 1722 et vers 1742.", "Two books, 1722 and around 1742.")),
 P("pl-05", "history", ("En quelle année le mur de Berlin tombe-t-il ?", "In which year did the Berlin Wall fall?"), [("1961", "1961"), ("1985", "1985"), ("1989", "1989"), ("1991", "1991")], 2, ("Le 9 novembre 1989.", "On 9 November 1989.")),
 P("pl-06", "history", ("Quel traité met fin à la guerre de Trente Ans ?", "Which treaty ended the Thirty Years' War?"), [("Utrecht", "Utrecht"), ("Westphalie", "Westphalia"), ("Vienne", "Vienna"), ("Versailles", "Versailles")], 1, ("1648, Münster et Osnabrück.", "1648, Münster and Osnabrück.")),
 P("pl-07", "politics", ("Combien de membres nommés compte le Conseil constitutionnel ?", "How many appointed members sit on the Constitutional Council?"), [("5", "5"), ("9", "9"), ("12", "12"), ("15", "15")], 1, ("Nommés pour neuf ans.", "Appointed for nine years.")),
 P("pl-08", "geopolitics", ("Combien de membres permanents compte le Conseil de sécurité de l'ONU ?", "How many permanent members does the UN Security Council have?"), [("3", "3"), ("5", "5"), ("10", "10"), ("15", "15")], 1, ("Chacun dispose d'un droit de veto.", "Each has a veto.")),
 P("pl-09", "vocabulary", ("« Il consulta ___ sa montre » : il voulait qu'on le remarque.", "“Il consulta ___ sa montre”: he wanted to be noticed."), [("manifestement", "manifestement"), ("ostensiblement", "ostensiblement"), ("prétendument", "prétendument"), ("incidemment", "incidemment")], 1, ("« Ostensiblement » implique l'intention d'être vu.", "“Ostensiblement” implies the intention of being seen.")),
 P("pl-10", "vocabulary", ("Quelle formule est correcte ?", "Which phrase is correct?"), [("Je vous serais gré de répondre", "Je vous serais gré de répondre"), ("Je vous saurais gré de répondre", "Je vous saurais gré de répondre"), ("Je vous sais gré de bien vouloir répondre demain", "Je vous sais gré de bien vouloir répondre demain"), ("Je vous saurai gré que vous répondiez", "Je vous saurai gré que vous répondiez")], 1, ("« Savoir gré » : on dit « je vous saurais gré de ».", "“Savoir gré”: the phrase is “je vous saurais gré de”.")),
]
write("quizzes/placement.json", placement)
