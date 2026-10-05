import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve('dist');
const routes = [
  '', 'features', 'education', 'screenshots', 'about', 'download', 'community', '404',
  'tr', 'tr/features', 'tr/education', 'tr/screenshots', 'tr/about', 'tr/download', 'tr/community', 'tr/404',
];
assert.ok(existsSync(root), 'Build website first with npm run build.');

for (const route of routes) {
  const file = route === '404' ? join(root, '404.html') : join(root, route, 'index.html');
  assert.ok(existsSync(file), `Missing rendered route: /${route}/`);
  const html = readFileSync(file, 'utf8');
  assert.match(html, /<main\b/, `Route has no main landmark: /${route}/`);
  assert.match(html, /<title>[^<]+<\/title>/, `Route has no title: /${route}/`);
  const expectedLanguage = route.startsWith('tr') ? 'tr' : 'en';
  assert.match(html, new RegExp(`<html[^>]+lang="${expectedLanguage}"`), `Wrong document language on /${route}/`);
  assert.match(html, /hreflang="en"/, `Missing English alternate on /${route}/`);
  assert.match(html, /hreflang="tr"/, `Missing Turkish alternate on /${route}/`);
  assert.match(html, /rel="canonical"/, `Missing canonical URL on /${route}/`);
  assert.match(html, /class="language-switch"[\s\S]*?lang="en"[\s\S]*?lang="tr"/, `Missing bilingual language switch on /${route}/`);
  assert.doesNotMatch(html, /(?:C:\\Users\\|C:\\velican\\|\/mnt\/[cd]\/|\/home\/no-labell\/)/i, `Local path leaked into /${route}/`);
  assert.doesNotMatch(html, /AtlasOS-[\w.-]+\.iso/i, `ISO artifact name leaked into /${route}/`);
}

function walk(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? walk(path) : [path];
  });
}

const htmlFiles = walk(root).filter((path) => path.endsWith('.html'));
for (const file of htmlFiles) {
  const html = readFileSync(file, 'utf8');
  for (const [, raw] of html.matchAll(/\b(?:href|src)="([^"]+)"/g)) {
    if (/^(?:https?:|mailto:|tel:|#|data:|javascript:)/i.test(raw)) continue;
    const clean = decodeURIComponent(raw.split(/[?#]/, 1)[0]);
    const local = clean.startsWith('/AtlasOS/') ? clean.slice('/AtlasOS/'.length) : clean.replace(/^\//, '');
    if (!local) continue;
    const target = join(root, local);
    const resolvedTarget = existsSync(target) && statSync(target).isDirectory() ? join(target, 'index.html') : target;
    assert.ok(existsSync(resolvedTarget), `Broken local reference in ${file}: ${raw}`);
  }
}

assert.equal(walk(root).some((path) => /\.(?:iso|img|squashfs)$/i.test(path)), false, 'Build output must not contain OS images.');

const sourceFiles = walk(resolve('src')).filter((path) => /\.(?:astro|css|ts|js)$/i.test(path));
const source = sourceFiles.map((path) => readFileSync(path, 'utf8')).join('\n');
assert.doesNotMatch(source, /AtlasPreview|class=["']desktop-preview|class=["']boot-card/i, 'Fabricated AtlasOS interface markup must not return.');

for (const screenshotPath of [join(root, 'screenshots', 'index.html'), join(root, 'tr', 'screenshots', 'index.html')]) {
  const html = readFileSync(screenshotPath, 'utf8');
  for (const image of ['atlasos-desktop-0.6.3-rc.webp', 'atlasos-live-desktop.jpeg', 'atlasos-boot-manager.png']) {
    assert.match(html, new RegExp(`/AtlasOS/images/(?:product/)?${image.replaceAll('.', '\\.')}`), `Authentic product capture missing from ${screenshotPath}: ${image}`);
  }
  assert.equal((html.match(/class="product-capture /g) || []).length, 3, `Expected three authentic captures in ${screenshotPath}.`);
  assert.doesNotMatch(html, /illustrative|mockup|simulation/i, `Screenshots must not describe fabricated product imagery: ${screenshotPath}`);
  const galleryFigures = [...html.matchAll(/<figure class="product-capture [\s\S]*?<\/figure>/g)].map(([figure]) => figure);
  assert.equal(galleryFigures.length, 3, `Expected three product gallery figures in ${screenshotPath}.`);
  for (const figure of galleryFigures) {
    assert.match(figure, /<img\b[^>]+\balt="[^"]+"[^>]+\bwidth="\d+"[^>]+\bheight="\d+"/, `Gallery image needs useful alt text and intrinsic dimensions: ${screenshotPath}`);
  }
}

for (const route of ['', 'features', 'education', 'screenshots', 'about', 'download', 'community']) {
  const html = readFileSync(join(root, route, 'index.html'), 'utf8');
  assert.match(html, /hreflang="tr"[^>]+href="https:\/\/chavooosss\.github\.io\/AtlasOS\/tr/, `English route lacks a Turkish equivalent: /${route}/`);
  assert.match(html, /© \d{4} AtlasOS contributors/, `English footer is missing: /${route}/`);
}
for (const route of ['tr', 'tr/features', 'tr/education', 'tr/screenshots', 'tr/about', 'tr/download', 'tr/community']) {
  const html = readFileSync(join(root, route, 'index.html'), 'utf8');
  assert.match(html, /hreflang="en"[^>]+href="https:\/\/chavooosss\.github\.io\/AtlasOS\/(?!tr\/)/, `Turkish route lacks an English equivalent: /${route}/`);
  assert.match(html, /© \d{4} AtlasOS’a katkı sunanlar/, `Turkish footer is not localized: /${route}/`);
  assert.doesNotMatch(html, /AtlasOS contributors/, `English footer text leaked into Turkish route: /${route}/`);
}
const sitemap = readFileSync(join(root, 'sitemap.xml'), 'utf8');
for (const route of ['features', 'education', 'screenshots', 'about', 'download', 'community']) {
  assert.ok(sitemap.includes(`https://chavooosss.github.io/AtlasOS/${route}/`), `Sitemap lacks English route /${route}/.`);
  assert.ok(sitemap.includes(`https://chavooosss.github.io/AtlasOS/tr/${route}/`), `Sitemap lacks Turkish route /tr/${route}/.`);
}
assert.ok(sitemap.includes('xmlns:xhtml='), 'Sitemap lacks xhtml namespace for localized alternates.');

const homeSource = readFileSync(resolve('src/components/pages/HomePage.astro'), 'utf8');
assert.match(homeSource, /prefers-reduced-motion:\s*reduce/, 'Immersive story must respect reduced-motion preferences.');
const styles = readFileSync(resolve('src/styles/global.css'), 'utf8');
assert.match(styles, /\.story-visual\s*\{\s*align-self:\s*stretch\s*;/, 'Sticky desktop-story image must span the chapter track.');
const layout = readFileSync(resolve('src/layouts/SiteLayout.astro'), 'utf8');
assert.match(layout, /atlas-logo-header\.png/, 'Transparent dark-header logo variant is missing.');
assert.match(layout, /hreflang="x-default"/, 'Default locale metadata is missing.');
assert.match(readFileSync(resolve('src/components/pages/NotFoundPage.astro'), 'utf8'), /location\.replace\("\/AtlasOS\/tr\/404\/"\)/, 'Turkish deep-link 404 fallback is missing.');
assert.ok(existsSync(join(root, 'images', 'atlas-logo-header.png')), 'Transparent header logo was not copied to the built site.');
assert.ok(existsSync(join(root, 'images', 'product', 'atlasos-desktop-0.6.3-rc.webp')), 'Optimized genuine RC screenshot was not copied to the built site.');

console.log(`Website checks passed: ${routes.length} English/Turkish routes, ${htmlFiles.length} HTML documents, local references, locale metadata, and authentic capture galleries.`);
