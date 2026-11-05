const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function screen() {
  const nodes = new Map();
  let stored;
  const context = {
    document: {
      getElementById(id) {
        if (!nodes.has(id)) nodes.set(id, {
          value:'', textContent:'', rows:[], replaceChildren(){},
          addEventListener(){}, classList:{remove(){}}
        });
        return nodes.get(id);
      },
      addEventListener(){}
    },
    localStorage: {
      getItem: () => null,
      setItem(key, value) { stored = value; }
    },
    confirm: () => true
  };
  vm.createContext(context);
  const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
  vm.runInContext(html.split('<script>')[1].split('</script>')[0], context);
  return {context, nodes, stored: () => stored};
}
function backup() {
  return {
    format:'jokbo-review', version:1,
    people:[{id:'parent',parentId:'',name_hanja:'格',sourceId:'scan'},
      {id:'child',parentId:'parent',name_hanja:'核'}],
    transcripts:[{id:'scan',name:'page.png',raw:'子格'}]
  };
}
function validate(state, data) {
  state.context.inputData = data;
  return vm.runInContext('validateBackup(inputData)', state.context);
}

test('Unicode names, relationships and OCR survive serialization', () => {
  const state = screen();
  assert.deepEqual(JSON.parse(JSON.stringify(validate(state, backup()))), {
    people:backup().people, transcripts:backup().transcripts
  });
});
test('reject duplicate IDs and missing sources or parents', () => {
  const state = screen();
  for (const change of [
    data => { data.people[1].id = 'parent'; },
    data => { data.people[1].parentId = 'missing'; },
    data => { data.people[0].sourceId = 'missing'; },
    data => { data.transcripts.push({...data.transcripts[0]}); }
  ]) {
    const data = backup();
    change(data);
    assert.throws(() => validate(state, data));
  }
});
test('reject self links and cycles across generations', () => {
  const state = screen();
  const data = backup();
  data.people[0].parentId = 'child';
  assert.throws(() => validate(state, data));
  data.people[0].parentId = 'parent';
  assert.throws(() => validate(state, data));
});
test('storage failure preserves current screen state', async () => {
  const state = screen();
  vm.runInContext("people = [{id:'keep',parentId:''}]", state.context);
  state.context.localStorage.setItem = () => { throw new Error('quota'); };
  const input = {files:[{size:100,text:async()=>JSON.stringify(backup())}]};
  await state.nodes.get('import-backup').onchange({target:input});
  assert.equal(vm.runInContext('people[0].id', state.context), 'keep');
  assert.match(state.nodes.get('status').textContent, /quota/);
  assert.equal(input.disabled, false);
});
test('declining replacement preserves current screen and storage', async () => {
  const state = screen();
  state.context.confirm = () => false;
  vm.runInContext("people = [{id:'keep',parentId:''}]", state.context);
  const input = {files:[{size:100,text:async()=>JSON.stringify(backup())}]};
  await state.nodes.get('import-backup').onchange({target:input});
  assert.equal(vm.runInContext('people[0].id', state.context), 'keep');
  assert.equal(state.stored(), undefined);
});
test('an empty valid backup restores and persists without stale data', async () => {
  const state = screen();
  vm.runInContext("people = [{id:'keep',parentId:''}]", state.context);
  const data = {format:'jokbo-review',version:1,people:[],transcripts:[]};
  const input = {files:[{size:100,text:async()=>JSON.stringify(data)}]};
  await state.nodes.get('import-backup').onchange({target:input});
  assert.equal(vm.runInContext('people.length', state.context), 0);
  assert.deepEqual(JSON.parse(state.stored()), {people:[],transcripts:[]});
});
