import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile, mkdir, mkdtemp, rm} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve, join} from 'node:path';
import {tmpdir} from 'node:os';
import {root, fixture} from './helpers.mjs';

if (!process.env.DISPLAY) throw new Error('Run this actual-toolbar test under a desktop display or xvfb-run -a.');
const html = await fixture('article.html');
const requests = [];
const server = createServer((req, res) => {
  requests.push(req.url);
  if (req.url === '/guides/article') { res.writeHead(200, {'Content-Type':'text/html'}); res.end(html); }
  else if (req.url === '/elsewhere') { res.writeHead(200, {'Content-Type':'text/html'}); res.end('<title>Another source page</title><p>Another page</p>'); }
  else { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const url = `http://127.0.0.1:${server.address().port}/guides/article`;
const profile = await mkdtemp(join(tmpdir(), 'gopher-reader-chromium-'));
let context;
try {
  context = await chromium.launchPersistentContext(profile, {
    channel:'chromium', headless:false, viewport:{width:1280,height:950},
    args:[`--disable-extensions-except=${resolve(root,'dist/chromium')}`,`--load-extension=${resolve(root,'dist/chromium')}`]
  });
  console.log('Chromium version:', context.browser().version());
  const errors = [];
  context.on('page', page => page.on('pageerror', error => errors.push(error.message)));
  let worker = context.serviceWorkers()[0];
  if (!worker) worker = await context.waitForEvent('serviceworker');
  const extensionId = new URL(worker.url()).hostname;
  const source = context.pages()[0];
  await source.goto(url); await source.waitForLoadState('networkidle');
  const before = requests.length;
  await source.bringToFront();
  const windowId = execFileSync('xdotool',['search','--onlyvisible','--class','[Cc]hromium'],{encoding:'utf8'}).trim().split('\n').at(-1);
  execFileSync('xdotool',['windowfocus','--sync',windowId]);
  const created = context.waitForEvent('page');
  execFileSync('xdotool',['key','--clearmodifiers','alt+shift+g']);
  const reader = await created;
  await reader.waitForSelector('#reading:not([hidden])', {timeout:15000});
  assert.equal(await reader.locator('#title').innerText(), 'A quieter way to read');
  assert.match(await reader.locator('#content').innerText(), /Keep the structure/);
  assert.doesNotMatch(await reader.locator('#content').innerText(), /RELATED PAGE SIDEBAR|SECRET INPUT|SECRET FORM|HIDDEN SECRET/);
  assert.equal(await source.locator('form').count(), 1, 'The original page must remain untouched');
  assert.equal(await source.evaluate(()=>window.sourceScriptRuns), 1);
  assert.equal(requests.length, before, 'Conversion must not fetch source pages or images again');
  assert.equal(await reader.locator('img,iframe,script[src^="http"]').count(), 0);
  assert.equal(await reader.locator('a[href^="javascript:"],a[href^="data:"]').count(), 0);
  const permissions = await worker.evaluate(async()=>chrome.permissions.getAll());
  assert.deepEqual(permissions.origins, [], 'No blanket host permissions');
  assert.ok(!permissions.permissions.includes('tabs'));
  const dataBefore = await worker.evaluate(async()=>chrome.storage.local.get(null));
  assert.ok(!JSON.stringify(dataBefore).includes('Reading on the web'), 'Page text must not persist');

  await reader.locator('[data-mode="page"]').click();
  assert.match(await reader.locator('#content').innerText(), /RELATED PAGE SIDEBAR/);
  assert.equal(await reader.locator('table').count(), 1);
  await reader.locator('[data-mode="links"]').click();
  assert.match(await reader.locator('#content').innerText(), /reference guide/);
  await reader.locator('[data-mode="article"]').click();
  await reader.locator('#find-open').click();
  await reader.locator('#find').fill('text');
  assert.ok(await reader.locator('mark').count() >= 2);
  await reader.locator('#find-close').click();
  await reader.locator('#font-up').click();
  assert.equal(await reader.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--reading-size').trim()), '19px');
  await reader.locator('#wrap').click();
  assert.ok(await reader.locator('#reading').evaluate(el=>el.classList.contains('nowrap')));
  await reader.locator('#wrap').click();
  await reader.locator('#theme').selectOption('dark');
  assert.equal(await reader.locator('html').getAttribute('data-theme'), 'dark');
  await reader.locator('#theme').selectOption('light');
  await reader.locator('#save').click();
  await reader.waitForFunction(()=>document.getElementById('save').textContent==='Saved');
  const saved = await worker.evaluate(async()=>chrome.storage.local.get(null));
  assert.equal(saved.savedPages.length, 1);
  assert.equal(saved.savedPages[0].url, url);
  assert.ok(!JSON.stringify(saved).includes('Reading on the web'));
  const downloadEvent = reader.waitForEvent('download');
  await reader.locator('#export').click();
  const download = await downloadEvent;
  const text = await readFile(await download.path(), 'utf8');
  assert.match(text, /A quieter way to read/); assert.match(text, /Links/);
  const cdp = await context.newCDPSession(source);
  await cdp.send('ServiceWorker.enable');
  await cdp.send('ServiceWorker.stopAllWorkers');
  await cdp.detach();
  await reader.reload(); await reader.waitForSelector('#reading:not([hidden])');
  assert.equal(await reader.locator('#save').getAttribute('aria-pressed'), 'true');
  await source.evaluate(()=>{const p=document.createElement('p');p.textContent='Updated after conversion.';document.querySelector('article').append(p);});
  await reader.locator('#refresh').click();
  await reader.waitForFunction(()=>document.getElementById('content').textContent.includes('Updated after conversion.'));
  await source.goto(`http://localhost:${server.address().port}/elsewhere`);
  await reader.locator('#refresh').click();
  await reader.waitForSelector('#error:not([hidden])');
  assert.match(await reader.locator('#error').innerText(), /changed/);
  assert.match(await reader.locator('#content').innerText(), /Updated after conversion/);
  await mkdir(join(root,'artifacts'),{recursive:true});
  await reader.locator('#error').evaluate(el=>el.hidden=true);
  await reader.screenshot({path:join(root,'artifacts/chromium-reader.png'),fullPage:true});
  await reader.setViewportSize({width:390,height:844});
  assert.ok(await reader.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth), 'Reader controls must fit a narrow viewport');
  await reader.screenshot({path:join(root,'artifacts/chromium-reader-mobile.png'),fullPage:true});
  const snapshotId = new URL(reader.url()).searchParams.get('id');
  await reader.close();
  await source.waitForTimeout(300);
  worker = context.serviceWorkers().find(item=>new URL(item.url()).hostname===extensionId) || await context.waitForEvent('serviceworker');
  const snapshots = await worker.evaluate(async()=>chrome.storage.session.get(null));
  assert.ok(!snapshots['snapshot:'+snapshotId], 'Closing a reading copy releases its text');
  const expired = await context.newPage();
  await expired.goto(`chrome-extension://${extensionId}/reader.html?id=${snapshotId}`);
  await expired.waitForSelector('#error:not([hidden])');
  assert.match(await expired.locator('#error').innerText(), /expired/);
  assert.deepEqual(errors, []);
  console.log('Chromium: actual shortcut/activeTab conversion, extraction, safe rendering, three views, find, settings, bookmarks, export, refresh, navigation boundary, cleanup, and narrow layout passed.');
} finally {
  if (context) await context.close();
  server.close();
  await rm(profile,{recursive:true,force:true});
}
