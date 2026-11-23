// Shared content model: load, validate and bundle the JSON under /content.
// The same rules are enforced in the app by CultureCore's ContentValidator.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
export const CONTENT_DIR = path.join(ROOT, 'content');

export const TOPICS = ['art', 'music', 'history', 'politics', 'geopolitics', 'books', 'philosophy'];
export const REGISTERS = ['courant', 'soutenu', 'litteraire', 'vieilli', 'familier'];
export const CATEGORIES = ['opera_ballet', 'classical', 'jazz_world', 'theatre_dance', 'exhibitions', 'science', 'literature_cinema'];
export const STATUSES = ['draft', 'in_review', 'published'];
export const EVENT_STATUSES = ['scheduled', 'cancelled', 'moved', 'sold_out'];

/** Collections the editor can open, mapped to files. */
export const COLLECTIONS = {
  ...Object.fromEntries(TOPICS.map((t) => [`cards:${t}`, `cards/${t}.json`])),
  vocab: 'vocab/vocab.json',
  vocabSets: 'vocab/sets.json',
  cities: 'events/cities.json',
  venues: 'events/venues.json',
  events: 'events/events.json',
  placement: 'quizzes/placement.json',
};

export async function readCollection(name, dir = CONTENT_DIR) {
  const file = COLLECTIONS[name];
  if (!file) throw new Error(`Unknown collection ${name}`);
  return JSON.parse(await readFile(path.join(dir, file), 'utf8'));
}

export async function writeCollection(name, items, dir = CONTENT_DIR) {
  const file = COLLECTIONS[name];
  if (!file) throw new Error(`Unknown collection ${name}`);
  await writeFile(path.join(dir, file), JSON.stringify(items, null, 2) + '\n', 'utf8');
}

export async function loadAll(dir = CONTENT_DIR) {
  const out = {};
  for (const name of Object.keys(COLLECTIONS)) out[name] = await readCollection(name, dir);
  out.cards = TOPICS.flatMap((t) => out[`cards:${t}`]);
  out.manifest = JSON.parse(await readFile(path.join(dir, 'manifest.json'), 'utf8'));
  return out;
}

const isBilingual = (v) => v && typeof v.fr === 'string' && typeof v.en === 'string' && v.fr.trim() && v.en.trim();
const isISODate = (s) => typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s));
const isISODateTime = (s) => typeof s === 'string' && /T\d{2}:\d{2}/.test(s) && /(Z|[+-]\d{2}:\d{2})$/.test(s) && !Number.isNaN(Date.parse(s));
const isURL = (s) => { try { const u = new URL(s); return u.protocol === 'https:'; } catch { return false; } };
const validTimeZone = (tz) => { try { new Intl.DateTimeFormat('en', { timeZone: tz }); return true; } catch { return false; } };

/** Returns { errors: [], warnings: [] } — errors block a build, warnings are informational. */
export function validate(content) {
  const errors = [];
  const warnings = [];
  const err = (id, msg) => errors.push(`${id}: ${msg}`);
  const warn = (id, msg) => warnings.push(`${id}: ${msg}`);
  const seen = new Set();
  const unique = (id) => { if (seen.has(id)) err(id, 'duplicate id'); seen.add(id); };

  const checkEditorial = (id, ed, { vocab = false, nativeReviewer } = {}) => {
    if (!ed || !STATUSES.includes(ed.status)) return err(id, 'invalid editorial.status');
    if (!Array.isArray(ed.sources)) return err(id, 'editorial.sources must be an array');
    for (const s of ed.sources) {
      if (!s.title) err(id, 'source without title');
      if (s.url && !isURL(s.url)) err(id, `source URL must be https: ${s.url}`);
    }
    if (ed.status === 'published') {
      if (ed.sources.length === 0) err(id, 'published without a source');
      if (!isISODate(ed.lastReviewed)) err(id, 'published without a valid lastReviewed date (yyyy-mm-dd)');
      if (!ed.reviewer) err(id, 'published without a reviewer');
      if (vocab && !nativeReviewer) err(id, 'published vocabulary needs a native-speaker reviewer');
    } else {
      if (ed.sources.length === 0) warn(id, 'no source yet');
      warn(id, `status ${ed.status} — needs review before publishing`);
    }
  };

  const checkImage = (id, img, where) => {
    if (!isURL(img.url)) err(id, `${where}.url must be https`);
    if (!img.license || !img.credit) err(id, `${where} needs licence and credit`);
    if (!isBilingual(img.altText)) err(id, `${where} needs bilingual alt text`);
    if (img.sourcePage && !isURL(img.sourcePage)) err(id, `${where}.sourcePage must be https`);
  };

  for (const t of TOPICS) {
    for (const c of content[`cards:${t}`]) {
      const id = c.id ?? '(card without id)';
      unique(id);
      if (c.topic !== t) err(id, `topic "${c.topic}" stored in cards/${t}.json`);
      if (!['standard', 'timeline', 'map'].includes(c.kind)) err(id, 'invalid kind');
      for (const f of ['title', 'body', 'takeaway']) if (!isBilingual(c[f])) err(id, `${f} must have FR and EN text`);
      if (c.quiz) {
        if (!isBilingual(c.quiz.question) || !isBilingual(c.quiz.explanation)) err(id, 'quiz question/explanation must be bilingual');
        if (!Array.isArray(c.quiz.options) || c.quiz.options.length < 2) err(id, 'quiz needs at least 2 options');
        else if (!(c.quiz.answerIndex >= 0 && c.quiz.answerIndex < c.quiz.options.length)) err(id, 'quiz answerIndex out of range');
        c.quiz.options?.forEach((o, i) => { if (!isBilingual(o)) err(id, `quiz option ${i} must be bilingual`); });
      } else warn(id, 'no micro-quiz');
      if (c.kind === 'timeline' && !(c.timeline?.length >= 2)) err(id, 'timeline card needs at least 2 timeline items');
      if (t === 'books') {
        if (!c.book?.author || !c.book?.year || !c.book?.originalTitle) err(id, 'book card needs book.author, book.year and book.originalTitle');
        if (c.book?.quote && !isBilingual(c.book.quoteTranslation)) err(id, 'book quote needs a bilingual translation');
      }
      if (t === 'geopolitics' && !isISODate(c.factsAsOf)) err(id, 'geopolitics card must have factsAsOf (yyyy-mm-dd)');
      if (c.image) checkImage(id, c.image, 'image');
      else warn(id, 'no licensed image yet');
      if (c.gallery && !Array.isArray(c.gallery)) err(id, 'gallery must be an array');
      (c.gallery ?? []).forEach((img, i) => checkImage(id, img, `gallery[${i}]`));
      if (c.gallery?.length && !c.image) err(id, 'gallery without a main image');
      if (!Array.isArray(c.tags)) err(id, 'tags must be an array');
      checkEditorial(id, c.editorial);
    }
  }

  const setIDs = new Set(content.vocabSets.map((s) => s.id));
  for (const v of content.vocab) {
    const id = v.id ?? '(vocab without id)';
    unique(id);
    for (const f of ['term', 'partOfSpeech', 'definition', 'gloss', 'example']) if (!v[f]?.trim?.()) err(id, `missing ${f}`);
    if (!REGISTERS.includes(v.register)) err(id, `invalid register ${v.register}`);
    if (!Array.isArray(v.nuances) || !Array.isArray(v.pitfalls)) err(id, 'nuances and pitfalls must be arrays');
    v.nuances?.forEach((n) => { if (!n.word || !isBilingual(n.note)) err(id, 'nuance needs word and bilingual note'); });
    for (const s of v.sets ?? []) if (!setIDs.has(s)) err(id, `unknown set ${s}`);
    if (v.exercise && (!['complete', 'rewrite'].includes(v.exercise.kind) || !v.exercise.answers?.length)) err(id, 'invalid exercise');
    checkEditorial(id, v.editorial, { vocab: true, nativeReviewer: v.nativeReviewer });
  }

  const cityTZ = Object.fromEntries(content.cities.map((c) => [c.id, c.timeZoneID]));
  for (const c of content.cities) {
    if (!validTimeZone(c.timeZoneID)) err(c.id, `invalid time zone ${c.timeZoneID}`);
    if (!isBilingual(c.name)) err(c.id, 'city name must be bilingual');
  }
  const venueCity = Object.fromEntries(content.venues.map((v) => [v.id, v.cityID]));
  for (const v of content.venues) {
    unique(v.id);
    if (!cityTZ[v.cityID]) err(v.id, `unknown city ${v.cityID}`);
    if (v.website && !isURL(v.website)) err(v.id, 'website must be https');
    if (typeof v.latitude !== 'number' || typeof v.longitude !== 'number') err(v.id, 'missing coordinates');
  }
  for (const e of content.events) {
    const id = e.id ?? '(event without id)';
    unique(id);
    if (!CATEGORIES.includes(e.category)) err(id, `invalid category ${e.category}`);
    if (!venueCity[e.venueID]) err(id, `unknown venue ${e.venueID}`);
    else if (venueCity[e.venueID] !== e.cityID) err(id, 'cityID does not match the venue city');
    if (!validTimeZone(e.timeZoneID)) err(id, `invalid time zone ${e.timeZoneID}`);
    else if (cityTZ[e.cityID] && cityTZ[e.cityID] !== e.timeZoneID) err(id, `time zone ${e.timeZoneID} differs from city zone ${cityTZ[e.cityID]}`);
    if (!isISODateTime(e.start)) err(id, 'start must be ISO-8601 with an offset');
    if (e.end && !isISODateTime(e.end)) err(id, 'end must be ISO-8601 with an offset');
    if (e.end && Date.parse(e.end) < Date.parse(e.start)) err(id, 'ends before it starts');
    if (isISODateTime(e.start) && validTimeZone(e.timeZoneID) && offsetMismatch(e.start, e.timeZoneID)) err(id, `start offset does not match ${e.timeZoneID} on that date`);
    if (!isURL(e.officialURL)) err(id, 'officialURL must be https');
    if (!e.sourceName) err(id, 'missing sourceName');
    if (!isISODateTime(e.lastChecked)) err(id, 'lastChecked must be an ISO-8601 timestamp');
    if (!EVENT_STATUSES.includes(e.status)) err(id, `invalid status ${e.status}`);
    if (!STATUSES.includes(e.editorialStatus)) err(id, 'invalid editorialStatus');
    const p = e.price ?? {};
    if (!p.isFree && p.minEUR == null && p.maxEUR == null) err(id, 'price range or isFree required');
    if (p.minEUR != null && p.maxEUR != null && p.minEUR > p.maxEUR) err(id, 'price min > max');
    if (e.image) checkImage(id, e.image, 'image');
    if ('imageURL' in e) err(id, 'imageURL is replaced by image (with licence)');
    if (e.isSample) warn(id, 'sample event — replace with a verified listing before publishing');
    if (e.editorialStatus === 'published' && e.isSample) err(id, 'sample events cannot be published');
  }

  for (const q of content.placement) {
    unique(q.id);
    if (!(q.quiz?.answerIndex >= 0 && q.quiz.answerIndex < (q.quiz.options?.length ?? 0))) err(q.id, 'placement answerIndex out of range');
  }
  return { errors, warnings };
}

/** True when the ISO offset of `iso` differs from the zone's real offset at that instant. */
export function offsetMismatch(iso, timeZone) {
  const m = iso.match(/(Z|([+-])(\d{2}):(\d{2}))$/);
  const declared = m[1] === 'Z' ? 0 : (m[2] === '-' ? -1 : 1) * (Number(m[3]) * 60 + Number(m[4]));
  return declared !== zoneOffsetMinutes(new Date(iso), timeZone);
}

export function zoneOffsetMinutes(date, timeZone) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-US', {
    timeZone, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).formatToParts(date).map((p) => [p.type, p.value]));
  const asUTC = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second);
  return Math.round((asUTC - date.getTime()) / 60000);
}

/** Local calendar day of an event in its venue's time zone (yyyy-mm-dd). */
export function localDay(iso, timeZone) {
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(iso));
}

/** Builds the single versioned bundle consumed by the app (ContentBundle in CultureCore). */
export function buildBundle(content) {
  return {
    version: content.manifest.version,
    generatedAt: content.manifest.generatedAt,
    cards: content.cards,
    vocab: content.vocab,
    vocabSets: content.vocabSets,
    cities: content.cities,
    venues: content.venues,
    events: content.events,
    placementQuiz: content.placement,
  };
}

export async function writeBundle(content, outFile) {
  await mkdir(path.dirname(outFile), { recursive: true });
  await writeFile(outFile, JSON.stringify(buildBundle(content)) + '\n', 'utf8');
}

export async function bumpManifest(dir = CONTENT_DIR) {
  const file = path.join(dir, 'manifest.json');
  const manifest = JSON.parse(await readFile(file, 'utf8'));
  manifest.version += 1;
  manifest.generatedAt = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
  await writeFile(file, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
  return manifest;
}
