// Landing page checks: the vendored Behnam Bagheri Design System is loaded in order and served.
// Run: node --test tests/site.test.mjs
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const DOCS = fileURLToPath(new URL('../docs/', import.meta.url));
const TYPES = { '.html': 'text/html', '.css': 'text/css', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.txt': 'text/plain' };
const DS_STYLES = ['ds/v1/tokens.css', 'ds/v1/base.css', 'ds/v1/components.css'];

let server;
let origin;

// Minimal static server, like GitHub Pages serving main:/docs.
before(async () => {
  server = createServer(async (req, res) => {
    const path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^[/\\]+/, '');
    const file = join(DOCS, path === '' ? 'index.html' : path);
    try {
      if (!file.startsWith(DOCS) || !(await stat(file)).isFile()) throw new Error('not a file');
      res.writeHead(200, { 'content-type': TYPES[extname(file)] || 'application/octet-stream' });
      res.end(await readFile(file));
    } catch {
      res.writeHead(404).end();
    }
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  origin = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

const page = () => fetch(`${origin}/`).then((r) => r.text());

test('page loads tokens, base, components, then site.css', async () => {
  const html = await page();
  const hrefs = [...html.matchAll(/<link rel="stylesheet" href="([^"?]+)(?:\?v=\w+)?">/g)].map((m) => m[1]);
  assert.deepEqual(hrefs, [...DS_STYLES, 'site.css']);
});

test('ds stylesheets, fonts and brand mark are served locally', async () => {
  const html = await page();
  for (const href of DS_STYLES) {
    const query = html.match(new RegExp(`${href.replace(/\./g, '\\.')}(\\?v=\\w+)?"`))[1] || '';
    const res = await fetch(`${origin}/${href}${query}`);
    assert.equal(res.status, 200, href);
    assert.match(res.headers.get('content-type'), /text\/css/);
    assert.match(await res.text(), /Behnam Bagheri Design System/);
  }
  const base = await (await fetch(`${origin}/ds/v1/base.css`)).text();
  for (const [, font] of base.matchAll(/url\('([^']+\.woff2)'\)/g)) {
    assert.equal((await fetch(`${origin}/ds/v1/${font}`)).status, 200, font);
  }
  assert.equal((await fetch(`${origin}/ds/bb-mark.svg`)).status, 200);
});

test('ds is vendored, not hotlinked, and old frameworks are gone', async () => {
  const html = await page();
  assert.doesNotMatch(html, /bea\.sh\/ds\//);
  assert.doesNotMatch(html, /daisyui|tailwindcss|fonts\.googleapis/);
  assert.match(html, /<html lang="en" data-product="blue">/);
  assert.match(html, /localStorage\.getItem\('bb-theme'\)/);
  assert.match(await readFile(join(DOCS, 'ds/VERSION'), 'utf8'), /^commit: [0-9a-f]{40}$/m);
});

test('site.css uses tokens, not hardcoded colors or fonts', async () => {
  const css = await readFile(join(DOCS, 'site.css'), 'utf8');
  assert.doesNotMatch(css, /#[0-9a-f]{3,8}\b|rgba?\(/i);
  assert.doesNotMatch(css, /font-family:(?!\s*var\()/);
});

test('SEO tags are unchanged', async () => {
  const html = await page();
  assert.match(html, /<link rel="canonical" href="https:\/\/behnambagheri\.github\.io\/fish-paste-gram\/">/);
  assert.equal((html.match(/application\/ld\+json/g) || []).length, 2);
});
