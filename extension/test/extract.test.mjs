import test from 'node:test';
import assert from 'node:assert/strict';
import {capture, fixture} from './helpers.mjs';

test('article extraction preserves structured writing and drops unrelated page chrome', async () => {
  const {dom, doc, core} = capture(await fixture('article.html'));
  const article = core.plainText(doc, 'article');
  assert.equal(doc.schemaVersion, 1);
  assert.equal(doc.source.title, 'A quieter way to read');
  assert.match(article, /Keep the structure/);
  assert.match(article, /if \(quiet\) \{\n  read\("text"\);\n\}/);
  assert.ok(doc.article.blocks.some(block => block.kind === 'listItem'));
  assert.ok(doc.article.blocks.some(block => block.kind === 'table'));
  assert.ok(doc.page.blocks.some(block => block.kind === 'quote'));
  assert.ok(doc.page.blocks.some(block => block.kind === 'image'));
  assert.doesNotMatch(article, /RELATED PAGE SIDEBAR/);
  assert.match(core.plainText(doc, 'page'), /RELATED PAGE SIDEBAR/);
  dom.window.close();
});

test('hidden content, scripts and form values never enter the document', async () => {
  const html = await fixture('article.html');
  const {dom, doc} = capture(html);
  const serialized = JSON.stringify(doc);
  assert.doesNotMatch(serialized, /HIDDEN SECRET|SECRET INPUT|SECRET FORM|sourceScriptRuns/);
  assert.match(serialized, /<img src=x onerror=alert\(1\)>/);
  assert.equal(dom.window.sourceScriptRuns, undefined);
  assert.ok(dom.window.document.querySelector('form'), 'Capture must not modify the original DOM');
  assert.ok(dom.window.document.querySelector('.hidden'));
  dom.window.close();
});

test('URLs resolve against base, links deduplicate, and unsafe schemes stay plain text', async () => {
  const {dom, doc, core} = capture(await fixture('article.html'));
  assert.ok(doc.links.some(link => link.url === 'https://fixture.test/reference#examples'));
  assert.ok(doc.links.some(link => link.url === 'gopher://example.org/1/'));
  assert.ok(doc.links.every(link => !/javascript:|data:|user:password/.test(link.url)));
  assert.match(core.plainText(doc), /Unsafe link/);
  const simple = capture(await fixture('directory.html'));
  assert.equal(simple.doc.links.length, 2);
  assert.equal(new Set(doc.links.map(link => link.url)).size, doc.links.length);
  dom.window.close(); simple.dom.window.close();
});

test('small directories have a useful fallback and link view', async () => {
  const {dom, doc, core} = capture(await fixture('directory.html'));
  assert.equal(doc.article.fallback, true);
  assert.match(core.plainText(doc), /First document/);
  assert.match(core.plainText(doc, 'links'), /\[1\] First document\n    https:\/\/fixture.test\/one/);
  dom.window.close();
});

test('language and reading direction survive conversion', async () => {
  const {dom, doc, core} = capture(await fixture('rtl.html'));
  assert.equal(doc.source.lang, 'ar');
  assert.equal(doc.source.dir, 'rtl');
  assert.match(core.plainText(doc), /نص عربي/);
  dom.window.close();
});

test('large documents are bounded and disclose truncation', () => {
  const {dom, doc, core} = capture('<html><head><title>Long</title></head><body><main>' + '<p>words '.repeat(1) + 'a'.repeat(240000) + '</p><p>Later</p></main></body></html>');
  assert.ok(doc.notices.length);
  assert.ok(core.plainText(doc).includes(`Note: ${doc.notices[0]}`), 'Export and native handoff must disclose shortened content');
  assert.ok(JSON.stringify(doc).length < 1800000);
  dom.window.close();
});

test('empty forms and non-web documents produce clear failures', () => {
  assert.throws(() => capture('<html><body><form><input value="Secret"></form></body></html>'), /no readable text/);
  assert.throws(() => capture('<html><body><p>Text</p></body></html>', 'file:///secret'), /ordinary web page/);
});

test('preferences and external URLs are constrained', async () => {
  const {dom, core, doc} = capture(await fixture('directory.html'));
  assert.equal(core.safeUrl('javascript:alert(1)'), null);
  assert.equal(core.safeUrl('https://user:password@example.org/'), null);
  assert.equal(core.safeUrl('/next', 'https://example.org/current'), 'https://example.org/next');
  assert.equal(core.prefs({fontSize:100, theme:'red', mode:'html', wrap:false}).fontSize, 26);
  assert.equal(core.prefs(null).fontSize, 18);
  assert.equal(core.prefs({theme:'red'}).theme, 'system');
  assert.throws(() => core.validate({...doc, schemaVersion:2}), /not valid/);
  assert.throws(() => core.validate({...doc, links:[{id:1, label:'Bad', url:'data:text/html,x'}]}), /invalid link/);
  dom.window.close();
});

test('XHTML forms remain excluded and lower-case elements retain structure', () => {
  const {dom, doc, core} = capture('<html xmlns="http://www.w3.org/1999/xhtml"><head><title>XHTML reading</title></head><body><main><h1>Reading</h1><p>Visible paragraph.</p><form><textarea>PRIVATE XML FORM</textarea></form><pre>  keep indentation</pre></main></body></html>', 'https://fixture.test/xml', {contentType:'application/xhtml+xml'});
  assert.doesNotMatch(JSON.stringify(doc), /PRIVATE XML FORM/);
  assert.match(core.plainText(doc), /Visible paragraph/);
  assert.ok(doc.page.blocks.some(block=>block.kind==='heading'));
  dom.window.close();
});

test('a single oversized paragraph keeps its readable beginning', () => {
  const {dom, doc, core} = capture('<html><head><title>Long paragraph</title></head><body><p>The beginning matters. '+ 'text '.repeat(60000) + '</p></body></html>');
  assert.ok(doc.notices.length);
  assert.match(core.plainText(doc), /The beginning matters/);
  assert.ok(JSON.stringify(doc).length<1800000);
  dom.window.close();
});

test('transparent content and named form controls stay excluded', () => {
  const {dom, doc} = capture('<html><head><title>Safe</title></head><body><p>Readable text.</p><div style="opacity:0">TRANSPARENT SECRET</div><form><input name="remove" value="SECRET NAMED CONTROL" /><textarea>SECRET FORM CONTENT</textarea></form></body></html>');
  assert.doesNotMatch(JSON.stringify(doc), /TRANSPARENT SECRET|SECRET NAMED CONTROL|SECRET FORM CONTENT/);
  dom.window.close();
});

test('paragraph boundaries inside quotes and table cells are not collapsed together', () => {
  const {dom, doc, core} = capture('<html><head><title>Nested blocks</title></head><body><blockquote><p>First quote.</p><p>Second quote.</p></blockquote><table><tr><td><p>First cell.</p><p>Second cell.</p></td></tr></table></body></html>');
  const text=core.plainText(doc,'page');
  assert.match(text,/First quote\.\n> Second quote\./);
  assert.match(text,/First cell\.\nSecond cell\./);
  dom.window.close();
});
