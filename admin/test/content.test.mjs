import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadAll, validate, localDay, offsetMismatch, buildBundle } from '../lib/content.mjs';

test('seed content has no validation errors', async () => {
  const { errors } = validate(await loadAll());
  assert.deepEqual(errors, []);
});

test('an event at 23:30 in Paris keeps its local date in Frankfurt and München', () => {
  const start = '2026-12-31T23:30:00+01:00';
  assert.equal(localDay(start, 'Europe/Paris'), '2026-12-31');
  assert.equal(localDay(start, 'Europe/Berlin'), '2026-12-31');
});

test('offset check catches a summer-time offset used in winter', () => {
  assert.equal(offsetMismatch('2026-12-31T23:30:00+01:00', 'Europe/Paris'), false);
  assert.equal(offsetMismatch('2026-12-31T23:30:00+02:00', 'Europe/Paris'), true);
  assert.equal(offsetMismatch('2026-07-14T21:00:00+02:00', 'Europe/Berlin'), false);
});

test('a published card without a source or review date is rejected', async () => {
  const content = await loadAll();
  const card = structuredClone(content['cards:art'][0]);
  card.editorial = { status: 'published', sources: [], lastReviewed: null, reviewer: null };
  content['cards:art'] = [card, ...content['cards:art'].slice(1)];
  content.cards = Object.keys(content).filter((k) => k.startsWith('cards:')).flatMap((k) => content[k]);
  const { errors } = validate(content);
  assert.ok(errors.includes(`${card.id}: published without a source`));
  assert.ok(errors.some((e) => e.startsWith(`${card.id}: published without a valid lastReviewed`)));
});

test('published vocabulary requires a native-speaker reviewer', async () => {
  const content = await loadAll();
  const entry = structuredClone(content.vocab[0]);
  entry.editorial = { ...entry.editorial, status: 'published', lastReviewed: '2026-11-22', reviewer: 'A' };
  entry.nativeReviewer = null;
  content.vocab = [entry];
  const { errors } = validate(content);
  assert.ok(errors.includes(`${entry.id}: published vocabulary needs a native-speaker reviewer`));
});

test('sample events cannot be published', async () => {
  const content = await loadAll();
  content.events = [{ ...content.events[0], editorialStatus: 'published' }];
  assert.ok(validate(content).errors.some((e) => e.endsWith('sample events cannot be published')));
});

test('bundle matches the app ContentBundle shape', async () => {
  const bundle = buildBundle(await loadAll());
  for (const key of ['version', 'generatedAt', 'cards', 'vocab', 'vocabSets', 'cities', 'venues', 'events', 'placementQuiz']) {
    assert.ok(key in bundle, key);
  }
  assert.equal(bundle.cards.length, 40);
});

test('no lyrics-like or unlicensed image fields slip in', async () => {
  const { cards } = await loadAll();
  for (const c of cards) {
    for (const img of [c.image, ...(c.gallery ?? [])].filter(Boolean)) {
      assert.ok(img.license && img.credit && img.altText?.fr && img.altText?.en, c.id);
      assert.match(img.url, /^https:\/\/(images\.metmuseum\.org|www\.artic\.edu)\//, `${c.id}: image host must be an open-access museum`);
    }
    assert.ok(!('lyrics' in c), c.id);
  }
});

test('a gallery image without a licence is an error', async () => {
  const content = await loadAll();
  const card = structuredClone(content['cards:art'][0]);
  card.image = { url: 'https://www.artic.edu/x.jpg', license: 'CC0', credit: 'AIC', altText: { fr: 'a', en: 'a' } };
  card.gallery = [{ url: 'https://www.artic.edu/y.jpg', license: '', credit: '', altText: { fr: 'b', en: 'b' } }];
  content['cards:art'] = [card];
  content.cards = [card];
  assert.ok(validate(content).errors.includes(`${card.id}: gallery[0] needs licence and credit`));
});
