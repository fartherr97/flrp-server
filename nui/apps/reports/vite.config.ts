import { flrpNui } from '../../shared/vite-nui';
import { resolve } from 'node:path';
const base = flrpNui(__dirname, resolve(__dirname, '../../../server-data/resources/[flrp]/flrp_reports/html')) as any;
// Inline the bundled Geist woff2 files so html/index.html stays the single file the manifest ships.
export default { ...base, build: { ...base.build, assetsInlineLimit: 4 * 1024 * 1024 } };
