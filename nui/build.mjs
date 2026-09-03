import { execSync } from 'node:child_process';
const map = { onduty: 'flrp_onduty', reports: 'flrp_reports', gunstores: 'flrp_gunstores', spawn: 'flrp_spawn' };
const apps = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(map);
for (const a of apps) {
  if (!map[a]) { console.error(`unknown app ${a}`); process.exit(1); }
  console.log(`\n▶ building ${a} → server-data/resources/[flrp]/${map[a]}/html`);
  execSync(`node_modules/.bin/vite build --config apps/${a}/vite.config.ts`, { stdio: 'inherit' });
}
console.log('\n✓ done');
