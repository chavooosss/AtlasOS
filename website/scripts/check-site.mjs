import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve('dist');
const routes = ['', 'features', 'education', 'screenshots', 'about', 'download', 'community', '404'];
assert.ok(existsSync(root), 'Build website first with npm run build.');

for (const route of routes) {
  const file = route === '404' ? join(root, '404.html') : join(root, route, 'index.html');
  assert.ok(existsSync(file), `Missing rendered route: /${route}/`);
  const html = readFileSync(file, 'utf8');
  assert.match(html, /<main\b/, `Route has no main landmark: /${route}/`);
  assert.match(html, /<title>[^<]+<\/title>/, `Route has no title: /${route}/`);
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
console.log(`Website smoke check passed: ${routes.length} routes, ${htmlFiles.length} HTML files, local links and images resolved.`);
