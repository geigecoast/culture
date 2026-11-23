#!/usr/bin/env node
// Culture editorial interface — zero-dependency Node server.
//
//   node admin/server.mjs            → http://127.0.0.1:4310
//
// Users and roles come from EDITOR_USERS ("name:role:token,…"; roles: editor, reviewer, native-reviewer).
// Without EDITOR_USERS the server only listens on localhost and treats you as a native reviewer.
import http from 'node:http';
import { readFile, appendFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { COLLECTIONS, readCollection, writeCollection, loadAll, validate, writeBundle, bumpManifest, ROOT } from './lib/content.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT ?? 4310);
const users = parseUsers(process.env.EDITOR_USERS);
const HOST = process.env.HOST ?? (users ? '0.0.0.0' : '127.0.0.1');

function parseUsers(raw) {
  if (!raw) return null;
  return Object.fromEntries(raw.split(',').map((entry) => {
    const [name, role, token] = entry.split(':');
    return [token, { name, role }];
  }));
}

function currentUser(req) {
  if (!users) return { name: 'local', role: 'native-reviewer' };
  const header = req.headers.authorization ?? '';
  const cookie = /(?:^|;\s*)culture_token=([^;]+)/.exec(req.headers.cookie ?? '')?.[1];
  const token = header.startsWith('Bearer ') ? header.slice(7) : cookie;
  return users[token] ?? null;
}

const canReview = (u) => u.role === 'reviewer' || u.role === 'native-reviewer';
const today = () => new Date().toISOString().slice(0, 10);

const TEMPLATES = {
  card: (topic) => ({
    id: '', topic, kind: 'standard', title: { fr: '', en: '' }, body: { fr: '', en: '' }, takeaway: { fr: '', en: '' },
    quiz: { question: { fr: '', en: '' }, options: [{ fr: '', en: '' }, { fr: '', en: '' }], answerIndex: 0, explanation: { fr: '', en: '' } },
    tags: [], imageSuggestion: '',
    image: { url: '', license: 'Domaine public (CC0)', credit: '', sourcePage: '', altText: { fr: '', en: '' } }, gallery: [], ...(topic === 'geopolitics' ? { factsAsOf: today() } : {}),
    editorial: { status: 'draft', sources: [{ title: '', publisher: '', url: '' }], lastReviewed: null, reviewer: null },
  }),
  vocab: () => ({
    id: '', term: '', partOfSpeech: '', register: 'soutenu', definition: '', gloss: '', example: '',
    nuances: [{ word: '', note: { fr: '', en: '' } }], pitfalls: [], etymology: '', sets: [],
    exercise: { kind: 'complete', prompt: '', answers: [''] },
    editorial: { status: 'draft', sources: [], lastReviewed: null, reviewer: null }, nativeReviewer: null,
  }),
  events: () => ({
    id: '', title: '', category: 'opera_ballet', cityID: 'paris', venueID: '', start: '', end: '', timeZoneID: 'Europe/Paris',
    price: { minEUR: null, maxEUR: null, isFree: false }, officialURL: '', sourceName: '', lastChecked: new Date().toISOString(),
    status: 'scheduled', editorialStatus: 'draft', description: { fr: '', en: '' },
  }),
  venues: () => ({ id: '', name: '', cityID: 'paris', address: '', latitude: 0, longitude: 0, website: '' }),
};

function templateFor(name) {
  if (name.startsWith('cards:')) return TEMPLATES.card(name.slice(6));
  return TEMPLATES[name]?.() ?? { id: '' };
}

function statusOf(item) {
  return item.editorial?.status ?? item.editorialStatus ?? null;
}

function setStatus(item, status) {
  if (item.editorial) item.editorial.status = status;
  else if ('editorialStatus' in item) item.editorialStatus = status;
}

async function audit(user, action, detail) {
  const line = JSON.stringify({ at: new Date().toISOString(), user: user.name, action, ...detail }) + '\n';
  await appendFile(path.join(HERE, 'audit.log'), line).catch(() => {});
}

async function body(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString('utf8');
  return raw ? JSON.parse(raw) : {};
}

function send(res, status, data, type = 'application/json; charset=utf-8') {
  res.writeHead(status, {
    'Content-Type': type,
    'X-Content-Type-Options': 'nosniff',
    'Content-Security-Policy': "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'",
  });
  res.end(typeof data === 'string' ? data : JSON.stringify(data));
}

/** Validates the whole content set with `items` replacing collection `name`; returns issues for `id`. */
async function issuesFor(name, items, id) {
  const content = await loadAll();
  content[name] = items;
  if (name.startsWith('cards:')) content.cards = Object.keys(COLLECTIONS).filter((k) => k.startsWith('cards:')).flatMap((k) => content[k]);
  const { errors, warnings } = validate(content);
  const mine = (list) => list.filter((m) => m.startsWith(`${id}:`)).map((m) => m.slice(id.length + 2));
  return { errors: mine(errors), warnings: mine(warnings) };
}

async function handleAPI(req, res, url, user) {
  const parts = url.pathname.split('/').filter(Boolean).slice(1).map(decodeURIComponent); // drop "api"

  if (parts[0] === 'whoami') return send(res, 200, user);

  if (parts[0] === 'collections' && parts.length === 1) {
    const list = [];
    for (const name of Object.keys(COLLECTIONS)) {
      const items = await readCollection(name);
      const counts = {};
      for (const item of items) { const s = statusOf(item) ?? 'n/a'; counts[s] = (counts[s] ?? 0) + 1; }
      list.push({ name, count: items.length, counts });
    }
    return send(res, 200, list);
  }

  const name = parts[1];
  if (parts[0] === 'collections' && !COLLECTIONS[name]) return send(res, 404, { error: 'unknown collection' });

  if (parts[0] === 'collections' && parts.length === 2 && req.method === 'GET') return send(res, 200, await readCollection(name));

  if (parts[0] === 'template') return send(res, 200, templateFor(name));

  if (parts[0] === 'collections' && parts.length >= 3) {
    const id = parts[2];
    const items = await readCollection(name);
    const index = items.findIndex((i) => i.id === id);

    if (req.method === 'GET' && parts.length === 3) {
      if (index < 0) return send(res, 404, { error: 'not found' });
      return send(res, 200, { item: items[index], issues: await issuesFor(name, items, id) });
    }

    if (req.method === 'PUT' && parts.length === 3) {
      const item = await body(req);
      if (!item.id || item.id !== id) return send(res, 400, { error: 'id in body must match URL' });
      // Editors cannot publish by editing; publishing goes through /publish.
      const previous = index >= 0 ? statusOf(items[index]) : null;
      if (statusOf(item) === 'published' && previous !== 'published') return send(res, 403, { error: 'Use “Publish” (reviewers only).' });
      if (previous === 'published' && !canReview(user)) setStatus(item, 'in_review');
      const next = [...items];
      if (index >= 0) next[index] = item; else next.push(item);
      const issues = await issuesFor(name, next, id);
      if (statusOf(item) === 'published' && issues.errors.length) return send(res, 422, { error: 'Published content must stay valid.', issues });
      await writeCollection(name, next);
      await audit(user, index >= 0 ? 'update' : 'create', { collection: name, id });
      return send(res, 200, { item, issues });
    }

    if (req.method === 'DELETE' && parts.length === 3) {
      if (index < 0) return send(res, 404, { error: 'not found' });
      if (statusOf(items[index]) === 'published' && !canReview(user)) return send(res, 403, { error: 'Only reviewers can delete published content.' });
      await writeCollection(name, items.filter((i) => i.id !== id));
      await audit(user, 'delete', { collection: name, id });
      return send(res, 200, { ok: true });
    }

    if (req.method === 'POST' && parts[3] === 'status') {
      if (index < 0) return send(res, 404, { error: 'not found' });
      const { status } = await body(req);
      const item = structuredClone(items[index]);
      if (status === 'published') {
        if (!canReview(user)) return send(res, 403, { error: 'Only reviewers can publish.' });
        if (name === 'vocab' && user.role !== 'native-reviewer') return send(res, 403, { error: 'Vocabulary needs a native-speaker reviewer.' });
        if (item.isSample) return send(res, 422, { error: 'Sample events cannot be published. Replace with a verified listing.' });
        if (item.editorial) {
          item.editorial.reviewer = user.name;
          item.editorial.lastReviewed = today();
        }
        if (name === 'vocab') item.nativeReviewer = user.name;
      } else if (!['draft', 'in_review'].includes(status)) {
        return send(res, 400, { error: 'invalid status' });
      }
      setStatus(item, status);
      const next = [...items];
      next[index] = item;
      const issues = await issuesFor(name, next, id);
      if (status === 'published' && issues.errors.length) return send(res, 422, { error: 'Fix the errors before publishing.', issues });
      await writeCollection(name, next);
      await audit(user, `status:${status}`, { collection: name, id });
      return send(res, 200, { item, issues });
    }
  }

  if (parts[0] === 'validate') {
    const content = await loadAll();
    return send(res, 200, { manifest: content.manifest, ...validate(content) });
  }

  if (parts[0] === 'bundle' && req.method === 'POST') {
    if (!canReview(user)) return send(res, 403, { error: 'Only reviewers can build a release bundle.' });
    let content = await loadAll();
    const { errors } = validate(content);
    if (errors.length) return send(res, 422, { error: 'Content has errors.', errors });
    await bumpManifest();
    content = await loadAll();
    const out = path.join(ROOT, 'App/Resources/SeedContent/content-bundle.json');
    await writeBundle(content, out);
    await audit(user, 'bundle', { version: content.manifest.version });
    return send(res, 200, { version: content.manifest.version, file: path.relative(ROOT, out) });
  }

  return send(res, 404, { error: 'not found' });
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host ?? 'localhost'}`);
    if (url.pathname === '/login' && req.method === 'POST') {
      const { token } = await body(req);
      if (!users?.[token]) return send(res, 401, { error: 'invalid token' });
      res.setHeader('Set-Cookie', `culture_token=${encodeURIComponent(token)}; HttpOnly; SameSite=Strict; Path=/`);
      return send(res, 200, users[token]);
    }
    if (url.pathname.startsWith('/api/')) {
      const user = currentUser(req);
      if (!user) return send(res, 401, { error: 'sign in required' });
      if (req.method !== 'GET' && req.headers['x-requested-with'] !== 'culture-editor') return send(res, 403, { error: 'missing CSRF header' });
      return await handleAPI(req, res, url, user);
    }
    const file = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
    if (!/^[\w.-]+$/.test(file)) return send(res, 404, 'Not found', 'text/plain');
    const types = { html: 'text/html; charset=utf-8', js: 'text/javascript; charset=utf-8', css: 'text/css; charset=utf-8' };
    const data = await readFile(path.join(HERE, 'public', file), 'utf8').catch(() => null);
    if (data == null) return send(res, 404, 'Not found', 'text/plain');
    return send(res, 200, data, types[file.split('.').pop()] ?? 'text/plain');
  } catch (error) {
    console.error(error);
    return send(res, 500, { error: String(error.message ?? error) });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Culture editor on http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT} ${users ? '(token sign-in)' : '(local mode)'}`);
});
