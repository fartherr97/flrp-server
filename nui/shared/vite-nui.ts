import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';
import { resolve } from 'node:path';

/** Build one FLRP NUI app into its resource's html/ as a single self-contained
 *  index.html (JS+CSS inlined) — the most robust form for FiveM (no hashed
 *  asset paths, one file to list). */
export function flrpNui(appDir: string, outDir: string) {
  return defineConfig({
    root: appDir,
    base: './',
    plugins: [react(), viteSingleFile()],
    resolve: { alias: { '@flrp': resolve(__dirname, '.') } },
    build: {
      outDir,
      emptyOutDir: true,
      target: 'chrome100',
      cssCodeSplit: false,
      reportCompressedSize: false,
      chunkSizeWarningLimit: 4000,
    },
  });
}
