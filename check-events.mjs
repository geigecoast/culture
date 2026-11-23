#!/usr/bin/env node
// Event-source maintenance report. Run daily (CI cron or server cron).
//  * events not re-checked in the last 24 h (the cancellation SLA in the spec);
//  * published events whose source terms have not been checked;
//  * venues with no registered source.
// Exit code 1 when a published event breaches the 24 h window.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { loadAll, ROOT } from './lib/content.mjs';

const MAX_AGE_HOURS = 24;
const now = Date.now();
const content = await loadAll();
const sources = JSON.parse(await readFile(path.join(ROOT, 'admin/sources.json'), 'utf8'));
const byVenue = Object.fromEntries(sources.map((s) => [s.venueID, s]));
let breaches = 0;

for (const v of content.venues) if (!byVenue[v.id]) console.log(`venue ${v.id}: no entry in admin/sources.json`);
for (const s of sources) if (!s.termsChecked) console.log(`source ${s.venueID}: terms of use not yet checked — do not ingest automatically`);

for (const e of content.events) {
  const end = Date.parse(e.end ?? e.start);
  if (end < now) continue;
  const ageHours = (now - Date.parse(e.lastChecked)) / 3.6e6;
  if (ageHours > MAX_AGE_HOURS) {
    const published = e.editorialStatus === 'published';
    if (published) breaches += 1;
    console.log(`${published ? 'STALE  ' : 'stale  '} ${e.id} last checked ${Math.round(ageHours)} h ago (${e.sourceName})`);
  }
}
console.log(breaches ? `${breaches} published event(s) older than ${MAX_AGE_HOURS} h.` : 'No published event breaches the 24 h window.');
process.exit(breaches ? 1 : 0);
