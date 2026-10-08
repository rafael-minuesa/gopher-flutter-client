import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scripts = await Promise.all(['node_modules/@mozilla/readability/Readability.js', 'src/core.js', 'src/extract.js'].map(file => readFile(resolve(root, file), 'utf8')));
export async function fixture(name) { return readFile(resolve(root, 'test/fixtures', name), 'utf8'); }
export function capture(html, url = 'https://fixture.test/guides/article', options = {}) {
  const dom = new JSDOM(html, {url, runScripts:'outside-only', pretendToBeVisual:true, ...options});
  dom.window.TextEncoder = TextEncoder;
  for (const script of scripts) dom.window.eval(script);
  const doc = JSON.parse(JSON.stringify(dom.window.GopherReader.capture()));
  return {dom, doc, core:dom.window.GopherDocument};
}
export {root};
