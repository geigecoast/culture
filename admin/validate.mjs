#!/usr/bin/env node
// Validates /content. Exit code 1 on errors. Usage: node admin/validate.mjs [--quiet] [--warnings]
import { loadAll, validate } from './lib/content.mjs';

const args = new Set(process.argv.slice(2));
const content = await loadAll();
const { errors, warnings } = validate(content);
if (args.has('--warnings')) for (const w of warnings) console.log(`warning  ${w}`);
for (const e of errors) console.error(`error    ${e}`);
if (!args.has('--quiet') || errors.length) {
  console.log(`${content.cards.length} cards, ${content.vocab.length} vocabulary entries, ${content.events.length} events, ` +
    `${content.venues.length} venues — ${errors.length} error(s), ${warnings.length} warning(s).`);
}
process.exit(errors.length ? 1 : 0);
