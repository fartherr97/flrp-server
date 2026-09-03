const preset = require('./tailwind-preset.cjs');
module.exports = (appGlob) => ({
  presets: [preset],
  content: [appGlob, __dirname + '/**/*.{ts,tsx}'],
  corePlugins: { preflight: true },
});
