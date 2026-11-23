// Culture editorial UI: a generic form editor over the /content collections.
const LABELS = {
  'cards:art': 'Art', 'cards:music': 'Musique', 'cards:history': 'Histoire', 'cards:politics': 'Politique',
  'cards:geopolitics': 'Géopolitique', 'cards:books': 'Livres', 'cards:philosophy': 'Philosophie', vocab: 'Vocabulaire', vocabSets: 'Séries de vocabulaire', cities: 'Villes',
  venues: 'Lieux', events: 'Événements', placement: 'Test de positionnement',
};
const STATUS_LABEL = { draft: 'Brouillon', in_review: 'En relecture', published: 'Publié' };
const ENUMS = {
  topic: ['art', 'music', 'history', 'politics', 'geopolitics', 'books', 'philosophy'], kind: ['standard', 'timeline', 'map', 'complete', 'rewrite'],
  register: ['courant', 'soutenu', 'litteraire', 'vieilli', 'familier'],
  category: ['opera_ballet', 'classical', 'jazz_world', 'theatre_dance', 'exhibitions', 'science', 'literature_cinema'],
  status: ['scheduled', 'cancelled', 'moved', 'sold_out'],
  editorialStatus: ['draft', 'in_review', 'published'],
};
const LONG_TEXT = new Set(['body', 'definition', 'example', 'explanation', 'description', 'note', 'statusNote', 'imageSuggestion', 'etymology', 'prompt']);

const state = { collection: 'cards:art', items: [], current: null, isNew: false, dirty: false, user: null };
const $ = (id) => document.getElementById(id);

async function api(path, options = {}) {
  const res = await fetch(`/api/${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'culture-editor', ...(options.headers ?? {}) },
  });
  if (res.status === 401) { $('login').hidden = false; throw new Error('Connexion requise'); }
  const data = await res.json();
  if (!res.ok) throw Object.assign(new Error(data.error ?? res.statusText), { data });
  return data;
}

const statusOf = (item) => item?.editorial?.status ?? item?.editorialStatus ?? null;
const titleOf = (item) => item.title?.fr ?? item.title ?? item.term ?? item.name?.fr ?? item.name ?? item.quiz?.question?.fr ?? item.id;

async function loadCollections() {
  const list = await api('collections');
  const nav = $('collections');
  nav.replaceChildren(...list.map(({ name, count, counts }) => {
    const b = document.createElement('button');
    b.className = name === state.collection ? 'active' : '';
    const pending = (counts.draft ?? 0) + (counts.in_review ?? 0);
    b.innerHTML = `<span></span><small title="${pending} à relire">${pending ? `${pending}/` : ''}${count}</small>`;
    b.firstChild.textContent = LABELS[name] ?? name;
    b.onclick = () => confirmDiscard() && selectCollection(name);
    return b;
  }));
}

async function selectCollection(name) {
  state.collection = name;
  state.items = await api(`collections/${encodeURIComponent(name)}`);
  showItem(null);
  renderList();
  loadCollections();
}

function renderList() {
  const q = $('search').value.toLowerCase();
  const status = $('statusFilter').value;
  const ul = $('items');
  ul.replaceChildren(...state.items
    .filter((i) => !status || statusOf(i) === status)
    .filter((i) => !q || JSON.stringify(i).toLowerCase().includes(q))
    .map((item) => {
      const li = document.createElement('li');
      li.className = item.id === state.current?.id ? 'active' : '';
      const s = statusOf(item);
      li.innerHTML = `<div class="t"></div><div class="id"></div>${s ? `<span class="badge ${s}">${STATUS_LABEL[s]}</span>` : ''}`;
      li.querySelector('.t').textContent = titleOf(item);
      li.querySelector('.id').textContent = item.id;
      li.onclick = () => confirmDiscard() && openItem(item.id);
      return li;
    }));
}

async function openItem(id) {
  const { item, issues } = await api(`collections/${encodeURIComponent(state.collection)}/${encodeURIComponent(id)}`);
  state.isNew = false;
  showItem(item, issues);
}

function showItem(item, issues = { errors: [], warnings: [] }) {
  state.current = item ? structuredClone(item) : null;
  state.dirty = false;
  $('empty').hidden = !!item;
  $('editorPane').hidden = !item;
  renderList();
  if (!item) return;
  $('itemTitle').textContent = titleOf(item) || 'Nouvel élément';
  const s = statusOf(item);
  $('itemStatus').textContent = s ? STATUS_LABEL[s] : '';
  $('itemStatus').className = `badge ${s ?? ''}`;
  const canReview = state.user?.role?.includes('reviewer');
  $('publish').hidden = !s;
  $('publish').disabled = !canReview || s === 'published' || item.isSample || state.isNew;
  $('publish').title = !canReview ? 'Réservé aux relecteurs' : item.isSample ? 'Les événements d\'exemple ne peuvent pas être publiés' : '';
  $('toReview').hidden = !s || s === 'in_review' || state.isNew;
  $('toDraft').hidden = !s || s === 'draft' || state.isNew;
  renderIssues(issues);
  renderForm();
  $('saveState').textContent = '';
}

function renderIssues({ errors, warnings }) {
  const box = $('issues');
  box.replaceChildren(
    ...errors.map((m) => Object.assign(document.createElement('div'), { className: 'err', textContent: `Erreur : ${m}` })),
    ...warnings.map((m) => Object.assign(document.createElement('div'), { className: 'warn', textContent: m })),
  );
}

function renderForm() {
  const form = $('form');
  form.replaceChildren(...Object.keys(state.current).map((key) => fieldFor(state.current, key, key)));
  $('raw').value = JSON.stringify(state.current, null, 2);
}

function markDirty() {
  state.dirty = true;
  $('saveState').textContent = 'Modifications non enregistrées';
  $('raw').value = JSON.stringify(state.current, null, 2);
}

const isBilingual = (v) => v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).sort().join() === 'en,fr';

function fieldFor(parent, key, label) {
  const value = parent[key];
  const wrap = document.createElement('div');
  wrap.className = 'field';
  const lab = document.createElement('label');
  lab.textContent = label;

  if (isBilingual(value)) {
    wrap.append(lab);
    const grid = document.createElement('div');
    grid.className = 'bilingual';
    for (const lang of ['fr', 'en']) {
      const cell = document.createElement('div');
      const ta = document.createElement('textarea');
      ta.value = value[lang];
      ta.lang = lang;
      ta.rows = LONG_TEXT.has(key) || Math.max(value.fr.length, value.en.length) > 90 ? 5 : 2;
      ta.setAttribute('aria-label', `${label} (${lang.toUpperCase()})`);
      ta.oninput = () => { value[lang] = ta.value; markDirty(); };
      cell.append(Object.assign(document.createElement('span'), { textContent: lang.toUpperCase() }), ta);
      grid.append(cell);
    }
    wrap.append(grid);
    return wrap;
  }

  if (Array.isArray(value)) {
    if (value.every((v) => typeof v === 'string')) {
      wrap.append(lab);
      const ta = document.createElement('textarea');
      ta.value = value.join('\n');
      ta.rows = Math.max(2, value.length);
      ta.placeholder = 'Une valeur par ligne';
      ta.oninput = () => { parent[key] = ta.value.split('\n').map((s) => s.trim()).filter(Boolean); markDirty(); };
      wrap.append(ta);
      return wrap;
    }
    const fs = document.createElement('fieldset');
    fs.append(Object.assign(document.createElement('legend'), { textContent: label }));
    value.forEach((entry, i) => {
      const item = document.createElement('div');
      item.className = 'array-item';
      const remove = Object.assign(document.createElement('button'), { type: 'button', className: 'ghost remove', textContent: '×', title: 'Retirer' });
      remove.onclick = () => { value.splice(i, 1); markDirty(); renderForm(); };
      item.append(remove);
      if (entry && typeof entry === 'object' && !isBilingual(entry)) {
        for (const k of Object.keys(entry)) item.append(fieldFor(entry, k, k));
      } else {
        item.append(fieldFor(value, i, `${label} ${i + 1}`));
      }
      fs.append(item);
    });
    const add = Object.assign(document.createElement('button'), { type: 'button', className: 'ghost', textContent: '+ Ajouter' });
    add.onclick = () => { value.push(blankLike(value[0])); markDirty(); renderForm(); };
    fs.append(add);
    return fs;
  }

  if (value && typeof value === 'object') {
    const fs = document.createElement('fieldset');
    fs.append(Object.assign(document.createElement('legend'), { textContent: label }));
    for (const k of Object.keys(value)) fs.append(fieldFor(value, k, k));
    return fs;
  }

  wrap.append(lab);
  let input;
  const editorialStatusField = key === 'editorialStatus' || (key === 'status' && Array.isArray(parent.sources));
  if ((ENUMS[key] || editorialStatusField) && typeof value === 'string') {
    input = document.createElement('select');
    const options = editorialStatusField ? ENUMS.editorialStatus : ENUMS[key];
    for (const opt of options) input.append(new Option(STATUS_LABEL[opt] ?? opt, opt, false, opt === value));
    // Editorial status changes go through the workflow buttons.
    if (editorialStatusField) { input.disabled = true; input.title = 'Utilisez les boutons de relecture'; }
    input.onchange = () => { parent[key] = input.value; markDirty(); };
  } else if (typeof value === 'boolean') {
    input = Object.assign(document.createElement('input'), { type: 'checkbox', checked: value });
    input.style.width = 'auto';
    input.onchange = () => { parent[key] = input.checked; markDirty(); };
  } else if (typeof value === 'number' || ['minEUR', 'maxEUR', 'latitude', 'longitude', 'answerIndex'].includes(key)) {
    input = Object.assign(document.createElement('input'), { type: 'number', step: 'any', value: value ?? '' });
    input.oninput = () => { parent[key] = input.value === '' ? null : Number(input.value); markDirty(); };
  } else {
    const long = LONG_TEXT.has(key) || (typeof value === 'string' && value.length > 90);
    input = document.createElement(long ? 'textarea' : 'input');
    if (long) input.rows = 4;
    input.value = value ?? '';
    if (['reviewer', 'lastReviewed', 'nativeReviewer'].includes(key)) { input.readOnly = true; input.title = 'Renseigné automatiquement à la publication'; }
    if (key === 'id' && !state.isNew) input.readOnly = true;
    input.oninput = () => { parent[key] = input.value === '' && value === null ? null : input.value; markDirty(); };
  }
  wrap.append(input);
  return wrap;
}

function blankLike(sample) {
  if (sample == null) return '';
  if (typeof sample === 'string') return '';
  if (typeof sample === 'number') return 0;
  if (typeof sample === 'boolean') return false;
  if (Array.isArray(sample)) return [];
  return Object.fromEntries(Object.entries(sample).map(([k, v]) => [k, blankLike(v)]));
}

function confirmDiscard() {
  return !state.dirty || confirm('Abandonner les modifications non enregistrées ?');
}

async function save() {
  const item = state.current;
  if (!item.id) return alert('Renseignez un identifiant (ex. art-009).');
  try {
    const { issues } = await api(`collections/${encodeURIComponent(state.collection)}/${encodeURIComponent(item.id)}`, { method: 'PUT', body: JSON.stringify(item) });
    state.items = await api(`collections/${encodeURIComponent(state.collection)}`);
    state.isNew = false;
    showItem(state.items.find((i) => i.id === item.id), issues);
    $('saveState').textContent = issues.errors.length ? 'Enregistré (avec erreurs)' : 'Enregistré';
    loadCollections();
  } catch (e) { alert(e.message); if (e.data?.issues) renderIssues(e.data.issues); }
}

async function changeStatus(status) {
  if (state.dirty) await save();
  try {
    const { item, issues } = await api(`collections/${encodeURIComponent(state.collection)}/${encodeURIComponent(state.current.id)}/status`, { method: 'POST', body: JSON.stringify({ status }) });
    state.items = await api(`collections/${encodeURIComponent(state.collection)}`);
    showItem(item, issues);
    loadCollections();
  } catch (e) { alert(e.message); if (e.data?.issues) renderIssues(e.data.issues); }
}

function report(title, lines) {
  $('reportTitle').textContent = title;
  $('reportBody').textContent = lines.join('\n') || 'Aucun problème.';
  $('report').showModal();
}

$('save').onclick = save;
$('publish').onclick = () => changeStatus('published');
$('toReview').onclick = () => changeStatus('in_review');
$('toDraft').onclick = () => changeStatus('draft');
$('search').oninput = renderList;
$('statusFilter').onchange = renderList;
$('applyRaw').onclick = () => {
  try { state.current = JSON.parse($('raw').value); markDirty(); renderForm(); } catch (e) { alert(`JSON invalide : ${e.message}`); }
};
$('newItem').onclick = async () => {
  if (!confirmDiscard()) return;
  const template = await api(`template/${encodeURIComponent(state.collection)}`);
  state.isNew = true;
  showItem(template);
  state.dirty = true;
};
$('delete').onclick = async () => {
  if (state.isNew) return showItem(null);
  if (!confirm(`Supprimer définitivement « ${state.current.id} » ?`)) return;
  try {
    await api(`collections/${encodeURIComponent(state.collection)}/${encodeURIComponent(state.current.id)}`, { method: 'DELETE' });
    state.dirty = false;
    await selectCollection(state.collection);
  } catch (e) { alert(e.message); }
};
$('validateAll').onclick = async () => {
  const { errors, warnings, manifest } = await api('validate');
  report(`Contenu v${manifest.version} — ${errors.length} erreur(s), ${warnings.length} avertissement(s)`, [...errors.map((e) => `ERREUR  ${e}`), ...warnings]);
};
$('buildBundle').onclick = async () => {
  if (!confirm('Valider le contenu et générer un nouveau bundle versionné pour l\'app ?')) return;
  try {
    const { version, file } = await api('bundle', { method: 'POST' });
    report('Bundle publié', [`Version ${version}`, file, '', 'Déployez ce fichier sur le stockage de contenu (voir README).']);
  } catch (e) { report('Bundle refusé', e.data?.errors ?? [e.message]); }
};
$('loginForm').onsubmit = async (ev) => {
  ev.preventDefault();
  const res = await fetch('/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token: $('token').value }) });
  if (!res.ok) { $('loginError').textContent = 'Jeton invalide'; return; }
  $('login').hidden = true;
  init();
};
window.addEventListener('beforeunload', (e) => { if (state.dirty) e.preventDefault(); });

async function init() {
  state.user = await api('whoami');
  $('who').textContent = `${state.user.name} · ${state.user.role}`;
  $('buildBundle').disabled = !state.user.role.includes('reviewer');
  await selectCollection(state.collection);
}
init().catch(() => {});
