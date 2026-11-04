const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../web/ocr.js'), 'utf8');

function setup({failPage = false} = {}) {
  const created = [];
  const context = vm.createContext({
    URL,
    document: {baseURI: 'https://example.test/app/'},
    Tesseract: {
      async createWorker(language, _mode, options) {
        created.push({language, options});
        if (failPage && language.includes('+kor')) throw Error('page model unavailable');
        return {
          async setParameters() {},
          async recognize() { return {data: {text: language}}; },
        };
      },
    },
  });
  vm.runInContext(source, context);
  return {recognize: context.jokboRecognize, created};
}

test('failed page initialization does not block the bundled column model', async () => {
  const {recognize, created} = setup({failPage: true});
  await assert.rejects(recognize('page'), /page model unavailable/);
  assert.equal(await recognize('column', true), 'chi_tra_vert');
  assert.equal(created[1].options.langPath, 'https://example.test/app/ocr-models/');
});

test('column-first OCR loads one worker and reuses it for later columns', async () => {
  const {recognize, created} = setup();
  await recognize('column-1', true);
  await recognize('column-2', true);
  assert.equal(created.length, 1);
  assert.equal(created[0].language, 'chi_tra_vert');
  assert.match(created[0].options.workerPath, /tesseract\.js@7\.0\.0/);
  assert.match(created[0].options.corePath, /tesseract\.js-core@7\.0\.0/);
});
