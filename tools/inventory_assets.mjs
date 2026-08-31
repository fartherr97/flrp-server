#!/usr/bin/env node
/* ==========================================================================
 * FLRP :: tools/inventory_assets.mjs — inventory an asset-import directory
 * --------------------------------------------------------------------------
 * Scans a directory of FiveM resources (e.g. ../asset-imports) and reports:
 *   - each resource + its manifest (fxmanifest.lua / __resource.lua)
 *   - category guess: vehicle | map/mlo | eup | script | dependency | unknown
 *   - escrow detection (.fxap present => escrowed/paid)
 *   - declared dependencies (`dependency` / `dependencies`)
 *   - vehicle spawn names (best-effort from vehicles.meta / carvariations.meta)
 *   - MLO / ymap presence, EUP streams
 *   - duplicate resource names + cross-resource name references
 *
 * This is a READ-ONLY reporter to support the workflow in docs/ASSET_IMPORT.md.
 * It never moves or modifies files. Output is human text + optional --json.
 *
 * Usage:  node tools/inventory_assets.mjs <dir> [--json]
 * ========================================================================== */
import { readdirSync, statSync, readFileSync, existsSync } from 'node:fs';
import { join, basename, extname } from 'node:path';

const dir = process.argv[2];
const asJson = process.argv.includes('--json');
if (!dir) {
  console.error('usage: node tools/inventory_assets.mjs <dir> [--json]');
  process.exit(1);
}
if (!existsSync(dir)) { console.error(`no such directory: ${dir}`); process.exit(1); }

function walk(root, maxDepth = 6, depth = 0, out = []) {
  let entries = [];
  try { entries = readdirSync(root, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    const p = join(root, e.name);
    if (e.isDirectory()) {
      if (depth < maxDepth) walk(p, maxDepth, depth + 1, out);
    } else {
      out.push(p);
    }
  }
  return out;
}

// A "resource" is any directory that directly contains a manifest.
function findResources(root) {
  const resources = [];
  const seen = new Set();
  for (const f of walk(root)) {
    const b = basename(f);
    if (b === 'fxmanifest.lua' || b === '__resource.lua') {
      const resDir = f.slice(0, f.length - b.length - 1);
      if (!seen.has(resDir)) { seen.add(resDir); resources.push(resDir); }
    }
  }
  return resources;
}

function safeRead(p) { try { return readFileSync(p, 'utf8'); } catch { return ''; } }

function listFiles(resDir) { return walk(resDir).map((p) => p.slice(resDir.length + 1)); }

function categorize(files, manifest) {
  const lc = files.map((f) => f.toLowerCase());
  const has = (re) => lc.some((f) => re.test(f));
  if (has(/vehicles\.meta$/) || has(/carvariations\.meta$/) || has(/carcols\.meta$/)) return 'vehicle';
  if (has(/\.ymap$/) || has(/_manifest\.ymf$/) || /data_file\s+['"]DLC_ITYP_REQUEST/i.test(manifest)) return 'map/mlo';
  if (has(/(^|\/)(mp_m_|mp_f_|uniform|eup).*\.(ydd|ytd)$/) || has(/streamedpeds/)) return 'eup';
  if (has(/\.lua$/) || has(/\.js$/) || has(/\.net\.dll$/)) return 'script';
  if (has(/\.(ydr|ytd|ydd|yft)$/)) return 'stream-asset';
  return 'unknown';
}

function extractDeps(manifest) {
  const deps = new Set();
  const single = manifest.match(/^\s*dependency\s+['"]([^'"]+)['"]/gm) || [];
  for (const m of single) { const g = m.match(/['"]([^'"]+)['"]/); if (g) deps.add(g[1]); }
  // dependencies { 'a', 'b' }
  const block = manifest.match(/dependencies\s*\{([^}]*)\}/s);
  if (block) { for (const g of block[1].matchAll(/['"]([^'"]+)['"]/g)) deps.add(g[1]); }
  return [...deps];
}

// Best-effort vehicle spawn names from vehicles.meta (<modelName>NAME</modelName>).
function extractSpawnNames(resDir, files) {
  const names = new Set();
  for (const rel of files) {
    if (!/vehicles\.meta$/i.test(rel)) continue;
    const text = safeRead(join(resDir, rel));
    for (const m of text.matchAll(/<modelName>\s*([A-Za-z0-9_]+)\s*<\/modelName>/gi)) {
      names.add(m[1].toLowerCase());
    }
  }
  return [...names];
}

const resources = findResources(dir).sort();
const report = [];
const nameCount = new Map();

for (const resDir of resources) {
  const name = basename(resDir);
  nameCount.set(name, (nameCount.get(name) || 0) + 1);
  const manifestPath = existsSync(join(resDir, 'fxmanifest.lua'))
    ? join(resDir, 'fxmanifest.lua') : join(resDir, '__resource.lua');
  const manifest = safeRead(manifestPath);
  const files = listFiles(resDir);
  const escrowed = files.some((f) => extname(f) === '.fxap');
  report.push({
    name,
    path: resDir,
    category: categorize(files, manifest),
    escrowed,
    dependencies: extractDeps(manifest),
    spawnNames: extractSpawnNames(resDir, files),
    hasMlo: files.some((f) => /\.ymap$/i.test(f)),
    fileCount: files.length,
  });
}

const duplicates = [...nameCount.entries()].filter(([, n]) => n > 1).map(([k]) => k);

if (asJson) {
  console.log(JSON.stringify({ root: dir, count: report.length, duplicates, resources: report }, null, 2));
} else {
  console.log(`FLRP asset inventory — ${dir}`);
  console.log(`Resources found: ${report.length}`);
  if (duplicates.length) console.log(`DUPLICATE resource names: ${duplicates.join(', ')}`);
  console.log('');
  const byCat = {};
  for (const r of report) (byCat[r.category] ||= []).push(r);
  for (const [cat, list] of Object.entries(byCat)) {
    console.log(`== ${cat} (${list.length}) ==`);
    for (const r of list) {
      const tags = [];
      if (r.escrowed) tags.push('ESCROWED');
      if (r.hasMlo) tags.push('MLO');
      if (r.spawnNames.length) tags.push(`${r.spawnNames.length} spawn name(s)`);
      if (r.dependencies.length) tags.push(`deps: ${r.dependencies.join(',')}`);
      console.log(`  - ${r.name}${tags.length ? '  [' + tags.join(' | ') + ']' : ''}`);
      if (r.spawnNames.length) console.log(`      spawns: ${r.spawnNames.join(', ')}`);
    }
    console.log('');
  }
  console.log('NOTE: read-only inventory. Nothing was moved or modified.');
  console.log('Next steps: see docs/ASSET_IMPORT.md');
}
