#!/usr/bin/env node
// Validates and writes the app bundle. Usage: node admin/build-bundle.mjs [--bump] [--out path]
import path from 'node:path';
import { loadAll, validate, writeBundle, bumpManifest, ROOT } from './lib/content.mjs';

const argv = process.argv.slice(2);
if (argv.includes('--bump')) await bumpManifest();
const outIndex = argv.indexOf('--out');
const out = outIndex >= 0 ? path.resolve(argv[outIndex + 1]) : path.join(ROOT, 'App/Resources/SeedContent/content-bundle.json');
const content = await loadAll();
const { errors } = validate(content);
if (errors.length) {
  console.error(errors.join('\n'));
  console.error('Bundle not written: fix the errors above.');
  process.exit(1);
}
await writeBundle(content, out);
console.log(`Wrote ${path.relative(ROOT, out)} (content v${content.manifest.version}).`);
