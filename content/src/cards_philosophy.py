from common import *
SEP = lambda slug, title: S(title, "Stanford Encyclopedia of Philosophy", f"https://plato.stanford.edu/entries/{slug}/")
GALLICA = S("Éditions anciennes numérisées", "Gallica — BnF", "https://gallica.bnf.fr")

def pcard(id, title, body, takeaway, q, sources, tags, book=None):
    c = card(id, "philosophy", title, body, takeaway, q, sources, tags=tags)
    if book: c["book"] = book
    return c

def book(author, year, original, quote, fr, en, source):
    return {"author": author, "year": year, "originalTitle": original, "quote": quote,
            "quoteTranslation": L(fr, en), "quoteSource": source}

philo = [
 pcard("ph-001", ("Socrate et la maïeutique", "Socrates and maieutics"),
  ("Socrate n'a rien écrit : nous le connaissons par Platon et Xénophon. Dans les rues d'Athènes, il interroge ses interlocuteurs jusqu'à leur faire reconnaître qu'ils ne savent pas ce qu'ils croyaient savoir. Il compare cette méthode, la maïeutique, au métier de sa mère, sage-femme : il aide les esprits à « accoucher » de la vérité. Accusé d'impiété et de corrompre la jeunesse, il est condamné à boire la ciguë en 399 av. J.-C.",
   "Socrates wrote nothing: we know him through Plato and Xenophon. In the streets of Athens he questioned people until they admitted they did not know what they thought they knew. He compared this method, maieutics, to the work of his mother, a midwife: he helped minds “give birth” to the truth. Accused of impiety and corrupting the young, he was condemned to drink hemlock in 399 BC."),
  ("Savoir qu'on ne sait pas est le début de la sagesse.", "Knowing that you do not know is the beginning of wisdom."),
  quiz(("Quel poison Socrate dut-il boire ?", "Which poison was Socrates made to drink?"),
       [("L'arsenic", "Arsenic"), ("La ciguë", "Hemlock"), ("La belladone", "Belladonna"), ("La mandragore", "Mandrake")],
       1, ("Platon raconte ses derniers instants dans le Phédon.", "Plato recounts his last moments in the Phaedo.")),
  [SEP("socrates", "Socrates")], ["antiquité", "grèce", "méthode"]),

 pcard("ph-002", ("Platon et l'allégorie de la caverne", "Plato's allegory of the cave"),
  ("Au livre VII de La République, Platon imagine des prisonniers enchaînés au fond d'une caverne, qui prennent pour la réalité les ombres projetées sur la paroi. Libéré, l'un d'eux découvre peu à peu le monde extérieur et le soleil, image du Bien. Redescendu pour libérer les autres, il est moqué, voire menacé. L'allégorie illustre l'éducation philosophique et justifie, chez Platon, que les philosophes gouvernent la cité.",
   "In Book VII of the Republic, Plato imagines prisoners chained deep in a cave, who take the shadows cast on the wall for reality. Freed, one of them gradually discovers the outside world and the sun, an image of the Good. When he goes back down to free the others, he is mocked, even threatened. The allegory illustrates philosophical education and, for Plato, justifies the rule of philosophers."),
  ("Sortir de la caverne : passer des apparences à la vérité.", "Leaving the cave: moving from appearances to truth."),
  quiz(("Dans quel ouvrage se trouve l'allégorie de la caverne ?", "In which work is the allegory of the cave found?"),
       [("Le Banquet", "The Symposium"), ("La République", "The Republic"), ("Les Lois", "The Laws"), ("L'Apologie de Socrate", "The Apology")],
       1, ("Livre VII, juste après les images du soleil et de la ligne.", "Book VII, right after the images of the sun and the divided line.")),
  [SEP("plato", "Plato")], ["antiquité", "grèce", "connaissance"]),

 pcard("ph-003", ("Aristote, l'animal politique", "Aristotle, the political animal"),
  ("Élève de Platon et précepteur du jeune Alexandre le Grand, Aristote fonde à Athènes son école, le Lycée. Dans la Politique, il affirme que l'homme est « un animal politique » : doué de la parole, il ne s'accomplit que dans la cité. Il classe les régimes selon le nombre de gouvernants et selon qu'ils servent l'intérêt commun ou celui des dirigeants.",
   "A pupil of Plato and tutor to the young Alexander the Great, Aristotle founded his school in Athens, the Lyceum. In the Politics he states that man is “a political animal”: gifted with speech, he only fulfils himself in the city. He classifies regimes by the number of rulers and by whether they serve the common interest or the rulers' own."),
  ("L'homme ne s'accomplit que dans la cité.", "Man only fulfils himself in the city."),
  quiz(("De quel futur conquérant Aristote fut-il le précepteur ?", "Which future conqueror did Aristotle tutor?"),
       [("Jules César", "Julius Caesar"), ("Alexandre le Grand", "Alexander the Great"), ("Hannibal", "Hannibal"), ("Périclès", "Pericles")],
       1, ("Il fut appelé à la cour de Macédoine par Philippe II.", "He was called to the Macedonian court by Philip II.")),
  [SEP("aristotle-politics", "Aristotle's Political Theory")], ["antiquité", "grèce", "politique"],
  book("Aristote (Ἀριστοτέλης)", "IVe siècle av. J.-C.", "Πολιτικά",
       "ἄνθρωπος φύσει πολιτικὸν ζῷον", "l'homme est par nature un animal politique",
       "man is by nature a political animal", "Politique, I, 2")),

 pcard("ph-004", ("Les stoïciens", "The Stoics"),
  ("Né à Athènes vers 300 av. J.-C., le stoïcisme enseigne à distinguer ce qui dépend de nous, nos jugements et nos actes, de ce qui n'en dépend pas : la santé, la réputation, la fortune. L'esclave affranchi Épictète, le conseiller de Néron Sénèque et l'empereur Marc Aurèle en sont les grandes figures romaines. Leur idéal : la sérénité par l'accord avec la raison et la nature.",
   "Born in Athens around 300 BC, Stoicism teaches us to tell apart what depends on us, our judgements and our actions, from what does not: health, reputation, fortune. The freed slave Epictetus, Nero's adviser Seneca and the emperor Marcus Aurelius are its great Roman figures. Their ideal: serenity through agreement with reason and nature."),
  ("Distinguer ce qui dépend de nous de ce qui n'en dépend pas.", "Tell apart what depends on us from what does not."),
  quiz(("Quel empereur romain a écrit des Pensées stoïciennes ?", "Which Roman emperor wrote Stoic Meditations?"),
       [("Auguste", "Augustus"), ("Néron", "Nero"), ("Marc Aurèle", "Marcus Aurelius"), ("Hadrien", "Hadrian")],
       2, ("Il les écrivit en grec, pour lui-même, pendant ses campagnes militaires.", "He wrote them in Greek, for himself, during his military campaigns.")),
  [SEP("stoicism", "Stoicism")], ["antiquité", "rome", "sagesse"],
  book("Épictète (Ἐπίκτητος)", "vers 125", "Ἐγχειρίδιον",
       "Τῶν ὄντων τὰ μέν ἐστιν ἐφ᾽ ἡμῖν, τὰ δὲ οὐκ ἐφ᾽ ἡμῖν.",
       "Parmi les choses, les unes dépendent de nous, les autres n'en dépendent pas.",
       "Some things are within our power, others are not.", "Manuel, 1")),

 pcard("ph-005", ("Descartes, « Je pense, donc je suis »", "Descartes, “I think, therefore I am”"),
  ("Dans le Discours de la méthode (1637), René Descartes décide de douter de tout ce qui peut l'être : les sens qui trompent, et même les raisonnements. Une certitude résiste : pendant qu'il doute, il pense, donc il existe. De ce point fixe, il entend reconstruire tout le savoir sur des idées « claires et distinctes ». La formule latine cogito, ergo sum apparaît dans les Principes de la philosophie (1644).",
   "In the Discourse on the Method (1637), René Descartes decides to doubt everything that can be doubted: the senses that deceive, and even reasoning. One certainty survives: while he doubts, he thinks, so he exists. From this fixed point he means to rebuild all knowledge on “clear and distinct” ideas. The Latin formula cogito, ergo sum appears in the Principles of Philosophy (1644)."),
  ("Le doute méthodique mène à une première certitude : je pense, donc je suis.", "Methodical doubt leads to a first certainty: I think, therefore I am."),
  quiz(("Dans quel livre paraît « Je pense, donc je suis » ?", "In which book does “I think, therefore I am” appear?"),
       [("Les Méditations métaphysiques", "Meditations on First Philosophy"), ("Le Discours de la méthode", "Discourse on the Method"), ("Les Pensées", "Pensées"), ("Le Traité des passions", "The Passions of the Soul")],
       1, ("Écrit en français, et non en latin, pour être lu par tous.", "Written in French, not Latin, so that anyone could read it.")),
  [SEP("descartes", "René Descartes"), GALLICA], ["xviie", "france", "raison"],
  book("René Descartes", "1637", "Discours de la méthode",
       "Je pense, donc je suis.", "Je pense, donc je suis.", "I think, therefore I am.", "4e partie")),

 pcard("ph-006", ("Pascal, le roseau pensant", "Pascal, the thinking reed"),
  ("Mathématicien et physicien de génie, Blaise Pascal se consacre après sa « nuit de feu » de 1654 à une apologie de la religion chrétienne, restée inachevée. Ses fragments sont publiés après sa mort sous le titre de Pensées (1670). L'homme y apparaît entre grandeur et misère : fragile comme un roseau, mais grand parce qu'il se sait mortel. Le célèbre « pari » invite l'incroyant à miser sur l'existence de Dieu.",
   "A brilliant mathematician and physicist, Blaise Pascal devoted himself after his “night of fire” in 1654 to a defence of the Christian religion, left unfinished. His fragments were published after his death as the Pensées (1670). Man appears there between greatness and wretchedness: fragile as a reed, yet great because he knows he is mortal. The famous “wager” invites the unbeliever to bet on God's existence."),
  ("Grandeur et misère de l'homme : un roseau, mais un roseau pensant.", "Man's greatness and wretchedness: a reed, but a thinking reed."),
  quiz(("Comment s'intitule le recueil posthume de Pascal ?", "What is Pascal's posthumous collection called?"),
       [("Les Essais", "The Essays"), ("Les Pensées", "The Pensées"), ("Les Maximes", "The Maxims"), ("Les Provinciales", "The Provincial Letters")],
       1, ("Les Provinciales, publiées de son vivant, défendent les jansénistes.", "The Provincial Letters, published in his lifetime, defend the Jansenists.")),
  [SEP("pascal", "Blaise Pascal"), GALLICA], ["xviie", "france", "foi"],
  book("Blaise Pascal", "publié en 1670", "Pensées",
       "Le cœur a ses raisons que la raison ne connaît point.",
       "Le cœur a ses raisons que la raison ne connaît point.",
       "The heart has its reasons, of which reason knows nothing.", "Pensées")),

 pcard("ph-007", ("Spinoza, Dieu ou la Nature", "Spinoza, God or Nature"),
  ("Exclu de la communauté juive d'Amsterdam en 1656 pour ses idées, Baruch Spinoza gagne sa vie en polissant des lentilles. Son Éthique, publiée après sa mort en 1677, est écrite « selon l'ordre géométrique », avec définitions et démonstrations. Il y identifie Dieu à la Nature elle-même et voit dans la connaissance de nos passions le chemin de la liberté et de la joie.",
   "Expelled from Amsterdam's Jewish community in 1656 for his ideas, Baruch Spinoza earned his living grinding lenses. His Ethics, published after his death in 1677, is written “in geometrical order”, with definitions and proofs. He identifies God with Nature itself and sees understanding our passions as the path to freedom and joy."),
  ("Comprendre ses passions, c'est commencer à s'en libérer.", "To understand one's passions is to begin to be free of them."),
  quiz(("Comment l'Éthique est-elle rédigée ?", "How is the Ethics written?"),
       [("En dialogues", "As dialogues"), ("En aphorismes", "As aphorisms"), ("Selon l'ordre géométrique", "In geometrical order"), ("En vers", "In verse")],
       2, ("Comme Euclide : définitions, axiomes, propositions et démonstrations.", "Like Euclid: definitions, axioms, propositions and proofs.")),
  [SEP("spinoza", "Baruch Spinoza")], ["xviie", "pays-bas", "liberté"],
  book("Baruch Spinoza", "publié en 1677", "Ethica, ordine geometrico demonstrata",
       "Deus sive Natura", "Dieu, c'est-à-dire la Nature", "God, or Nature", "Éthique, IV, préface")),

 pcard("ph-008", ("Kant, « Ose savoir ! »", "Kant, “Dare to know!”"),
  ("En 1784, à Königsberg, Emmanuel Kant répond à la question « Qu'est-ce que les Lumières ? » : c'est la sortie de l'homme hors de l'état de minorité dont il est lui-même responsable. Sa devise : Sapere aude, ose te servir de ton propre entendement. En morale, il formule l'impératif catégorique : agis seulement selon une règle dont tu pourrais vouloir qu'elle devienne une loi universelle.",
   "In 1784, in Königsberg, Immanuel Kant answered the question “What is Enlightenment?”: it is man's emergence from his self-incurred immaturity. His motto: Sapere aude, dare to use your own understanding. In ethics he formulated the categorical imperative: act only on a rule you could will to become a universal law."),
  ("Penser par soi-même : la devise des Lumières.", "Thinking for oneself: the motto of the Enlightenment."),
  quiz(("Dans quelle ville Kant a-t-il passé presque toute sa vie ?", "In which city did Kant spend almost his whole life?"),
       [("Berlin", "Berlin"), ("Königsberg", "Königsberg"), ("Vienne", "Vienna"), ("Iéna", "Jena")],
       1, ("Aujourd'hui Kaliningrad, en Russie.", "Today Kaliningrad, in Russia.")),
  [SEP("kant", "Immanuel Kant")], ["lumières", "allemagne", "morale"],
  book("Immanuel Kant", "1784", "Beantwortung der Frage: Was ist Aufklärung?",
       "Sapere aude! Habe Mut, dich deines eigenen Verstandes zu bedienen!",
       "Sapere aude ! Aie le courage de te servir de ton propre entendement !",
       "Sapere aude! Have the courage to use your own understanding!", "« Qu'est-ce que les Lumières ? »")),

 pcard("ph-009", ("Nietzsche, la mort de Dieu", "Nietzsche, the death of God"),
  ("Dans Le Gai Savoir (1882), Friedrich Nietzsche fait annoncer par un insensé que « Dieu est mort » : non une affirmation théologique, mais le constat que les valeurs héritées du christianisme ont perdu leur fondement. Le risque est le nihilisme. Sa réponse : créer de nouvelles valeurs, figure du surhumain dans Ainsi parlait Zarathoustra, et affirmer la vie à travers la « volonté de puissance ».",
   "In The Gay Science (1882), Friedrich Nietzsche has a madman announce that “God is dead”: not a theological claim, but the observation that values inherited from Christianity have lost their foundation. The danger is nihilism. His answer: create new values, the figure of the overman in Thus Spoke Zarathustra, and affirm life through the “will to power”."),
  ("Après la mort de Dieu, créer ses propres valeurs.", "After the death of God, create one's own values."),
  quiz(("Dans quel livre paraît l'annonce « Dieu est mort » ?", "In which book is “God is dead” announced?"),
       [("Ainsi parlait Zarathoustra", "Thus Spoke Zarathustra"), ("Le Gai Savoir", "The Gay Science"), ("Par-delà bien et mal", "Beyond Good and Evil"), ("L'Antéchrist", "The Antichrist")],
       1, ("Paragraphe 125, « L'insensé » ; le thème revient dans Zarathoustra.", "Section 125, “The Madman”; the theme returns in Zarathustra.")),
  [SEP("nietzsche", "Friedrich Nietzsche")], ["xixe", "allemagne", "valeurs", "pouvoir"],
  book("Friedrich Nietzsche", "1882", "Die fröhliche Wissenschaft",
       "Gott ist todt!", "Dieu est mort !", "God is dead!", "Le Gai Savoir, § 125")),
]
write("cards/philosophy.json", philo)
