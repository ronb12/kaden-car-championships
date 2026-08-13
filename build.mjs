/**
 * Copies root-level static game assets into dist/ for Vercel when
 * outputDirectory is "dist" (avoids serving only an incomplete public/).
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = __dirname;
const out = path.join(root, 'dist');

const files = [
  'index.html',
  'garage.html',
  'settings.html',
  'privacy.html',
  'terms.html',
  'robots.txt',
  'sitemap.xml',
  'ads.txt',
  'app-ads.txt',
  'three.min.js',
  'GLTFLoader.js',
  'krc-car-3d.js',
  'favicon.ico',
  'app-icon.png',
  'ads.txt',
  'app-ads.txt',
  'menu-bg.png',
];

fs.mkdirSync(out, { recursive: true });

for (const name of files) {
  const src = path.join(root, name);
  if (!fs.existsSync(src)) {
    console.warn(`build: skip missing ${name}`);
    continue;
  }
  fs.copyFileSync(src, path.join(out, name));
}

const carsSrc = path.join(root, 'garage-cars');
const carsDest = path.join(out, 'garage-cars');
if (fs.existsSync(carsSrc)) {
  fs.cpSync(carsSrc, carsDest, { recursive: true, force: true });
  const car30 = path.join(carsDest, 'car-30.png');
  if (!fs.existsSync(car30)) {
    const car29 = path.join(carsDest, 'car-29.png');
    if (fs.existsSync(car29)) fs.copyFileSync(car29, car30);
  }
}

const modelsSrc = path.join(root, 'public', 'models');
const modelsDest = path.join(out, 'models');
const modelsRoot = path.join(root, 'models');
if (fs.existsSync(modelsSrc)) {
  fs.cpSync(modelsSrc, modelsDest, { recursive: true, force: true });
  // Local `python -m http.server` serves repo root — mirror models/ beside index.html.
  fs.cpSync(modelsSrc, modelsRoot, { recursive: true, force: true });
}

console.log('build: wrote static assets to dist/');
