// Pinned resvg renderer: no network inputs, system fonts, randomness or app changes.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Resvg } = require('@resvg/resvg-js');
const layers = ['background.svg', 'route.svg', 'shading.svg'];
const inner = name => fs.readFileSync(path.join(__dirname, name), 'utf8')
  .replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">' +
  layers.map(inner).join('\n') + '</svg>';
const output = path.join(__dirname, 'output');
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, 'icon.svg'), svg);
const bytes = new Resvg(svg, { font: { loadSystemFonts: false } }).render().asPng();
fs.writeFileSync(path.join(output, 'icon.png'), bytes);
fs.writeFileSync(path.join(output, 'render.sha256'), crypto.createHash('sha256').update(bytes).digest('hex') + '\n');
console.log('Rendered review-only 1024px icon. The app asset was not changed.');
