const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const listeners = {};
function element(id) {
  return {id, value:'', textContent:'', hidden:false, disabled:false, style:{},
    addEventListener(event, fn) { listeners[id + ':' + event] = fn; },
    replaceChildren() { this.children = []; }, appendChild(child) { (this.children ||= []).push(child); },
    getContext() {return {clearRect(){},drawImage(){},fillRect(){},strokeRect(){}};},
    getBoundingClientRect() { return {left:0,top:0,width:100,height:100}; },
    toBlob(cb) { cb({size:20}); }, click(){}, remove(){}, setPointerCapture(){}};
}
const ids = ['canvas','file','surname','raw','edited','status','read','parse','reset','save','empty','candidates','count'];
const els = Object.fromEntries(ids.map(id => [id, element(id)]));
let requests = [], fail = false, confirmations = true;
class FakeImage { set src(value) { this.naturalWidth=100; this.naturalHeight=100; this.onload(); } }
const context = {document:{getElementById:id=>els[id],createElement:tag=>element(tag),body:element('body')},
  Image:FakeImage, URL:{createObjectURL:()=> 'blob:test',revokeObjectURL(){}}, Blob,
  confirm:()=>confirmations, setTimeout:fn=>fn(),
  fetch:async(path, options)=>{
    requests.push({path,options});
    if (fail) return {ok:false,json:async()=>({error:'시험 오류'})};
    return {ok:true,json:async()=> path==='/ocr'
      ? {raw:'子 格 壬辰生',candidates:[{name_hanja:'格',relation:'아들 후보'}]}
      : {raw:'ignored',candidates:[{name_hanja:'核',relation:'아들 후보'}]}};
  }};
vm.runInNewContext(fs.readFileSync(__dirname+'/app.js','utf8'), context);
(async()=>{
  await listeners['file:change']({target:{files:[{name:'test.jpg',type:'image/jpeg',size:20}],value:''}});
  await listeners['read:click']();
  assert.equal(requests[0].path,'/ocr');
  assert.equal(els.raw.value,'子 格 壬辰生');
  assert.equal(els.count.textContent,'1건');
  assert.match(els.candidates.children[0].textContent,/格/);
  els.edited.value='子 核 丁酉生';
  await listeners['parse:click']();
  assert.equal(requests[1].path,'/parse');
  assert.equal(els.raw.value,'子 格 壬辰生');
  assert.match(els.candidates.children[0].textContent,/核/);
  fail=true;
  await listeners['read:click']();
  assert.equal(els.raw.value,'子 格 壬辰生');
  assert.match(els.status.textContent,/판독 실패/);
  confirmations=false;
  await listeners['file:change']({target:{files:[{name:'next.jpg',type:'image/jpeg',size:20}],value:''}});
  assert.equal(els.edited.value,'子 核 丁酉生');
  console.log('desktop UI OCR success, reparse, failure preservation and cancellation: PASS');
})().catch(e=>{console.error(e);process.exitCode=1;});
