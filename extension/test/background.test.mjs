import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
import {webcrypto} from 'node:crypto';
import {root} from './helpers.mjs';
import {join} from 'node:path';
const coreCode = await readFile(join(root,'src/core.js'),'utf8');
const code = await readFile(join(root,'src/background.js'),'utf8');
const id = '11111111-1111-4111-8111-111111111111';
const document = {schemaVersion:1, source:{url:'https://example.org/page',title:'Private reading copy'},
 article:{blocks:[{kind:'paragraph',inlines:[{text:'Secret page text'}]}]},page:{blocks:[]},links:[]};
function harness() {
  const session = {}, local = {}, listeners = {}, open = [];
  function area(data) { return {
    async get(keys) { if (keys===null) return {...data}; const result={}; for(const key of typeof keys==='string'?[keys]:keys) result[key]=data[key]; return result; },
    async set(values) { Object.assign(data,values); },
    async remove(keys) { for(const key of typeof keys==='string'?[keys]:keys) delete data[key]; }
  }; }
  const api = {
    runtime:{id:'test',getURL:path=>'chrome-extension://test/'+path,onMessage:{addListener:fn=>listeners.message=fn}},
    storage:{session:area(session),local:area(local)},
    action:{onClicked:{addListener:fn=>listeners.action=fn},async setBadgeText(){}},
    tabs:{onRemoved:{addListener:fn=>listeners.removed=fn},async get(tabId){return {id:tabId,url:document.source.url};},async create(tab){open.push(tab); return {id:22};}},
    scripting:{async executeScript(options){return options.files?[]:[{frameId:0,result:document}];}}
  };
  const context=vm.createContext({browser:api,URL,TextEncoder,crypto:webcrypto,console});
  vm.runInContext(coreCode,context); vm.runInContext(code,context);
  const sender={id:'test',url:'chrome-extension://test/reader.html?id='+id};
  async function message(value,from=sender) {
    return new Promise(resolve=>{
      const accepted=listeners.message(value,from,result=>resolve(result));
      if(!accepted) resolve(null);
    });
  }
  session['snapshot:'+id]={id,sourceTabId:1,readerTabId:22,document};
  return {session,local,listeners,api,open,message};
}

test('messages from web pages and content scripts are rejected', async()=>{
  const h=harness();
  assert.equal(await h.message({type:'load',id},{id:'test',url:'https://example.org'}),null);
  assert.equal(await h.message({type:'load',id},{id:'other',url:'chrome-extension://test/reader.html'}),null);
  assert.equal((await h.message({type:'load',id})).ok,true);
});

test('bookmarks persist only metadata and concurrent operations keep both entries', async()=>{
  const h=harness();
  const second='22222222-2222-4222-8222-222222222222';
  h.session['snapshot:'+second]={id:second,document:{...document,source:{url:'https://example.org/second',title:'Second'}}};
  const results=await Promise.all([h.message({type:'saved.toggle',id}),h.message({type:'saved.toggle',id:second})]);
  assert.ok(results.every(result=>result.ok));
  assert.equal(h.local.savedPages.length,2);
  assert.doesNotMatch(JSON.stringify(h.local),/Secret page text/);
});

test('failed refresh preserves the existing copy and changed tabs cannot be captured', async()=>{
  const h=harness();
  h.api.tabs.get=async()=>({id:1,url:'https://elsewhere.test'});
  const result=await h.message({type:'refresh',id});
  assert.equal(result.ok,false); assert.match(result.error,/changed/);
  assert.equal(h.session['snapshot:'+id].document,document);
});

test('closing the reader releases the snapshot, and invalid IDs report an error', async()=>{
  const h=harness();
  h.listeners.removed(22);
  await new Promise(resolve=>setTimeout(resolve,10));
  assert.equal(h.session['snapshot:'+id],undefined);
  assert.match((await h.message({type:'load',id})).error,/expired/);
  assert.equal((await h.message({type:'load',id:'bad'})).ok,false);
});

test('settings are constrained and unknown actions return an error', async()=>{
  const h=harness();
  const result=await h.message({type:'preferences',value:{fontSize:1,theme:'javascript',mode:'arbitrary'}});
  assert.equal(result.preferences.fontSize,14);
  assert.equal(h.local.preferences.theme,'system');
  assert.equal((await h.message({type:'arbitrary'})).ok,false);
});

test('native handoff uses the stored copy and handles missing and incompatible companions', async()=>{
  const h=harness();
  let sent;
  h.api.runtime.sendNativeMessage=async(host,message)=>{
    assert.equal(host,'org.gopherclient.reader'); sent=message;
    return {ok:true,url:'gopher://127.0.0.1:7070/1/page/'+id};
  };
  assert.equal((await h.message({type:'native.open',id,page:{url:'file:///untrusted'}})).ok,true);
  assert.equal(sent.id,id);
  assert.equal(sent.page.url,document.source.url);
  assert.match(sent.page.article,/Secret page text/);
  assert.equal(sent.protocolVersion,1);
  h.api.runtime.sendNativeMessage=async()=>{throw new Error('Native host not found');};
  assert.match((await h.message({type:'native.open',id})).error,/Install the Linux app/);
  h.api.runtime.sendNativeMessage=async()=>({ok:true,url:'https://untrusted.example'});
  assert.match((await h.message({type:'native.open',id})).error,/invalid page address/);
  h.api.runtime.sendNativeMessage=async()=>({ok:false,error:'Library full'});
  assert.equal((await h.message({type:'native.open',id})).error,'Library full');
});
