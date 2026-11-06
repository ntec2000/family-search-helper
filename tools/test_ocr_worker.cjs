const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../web/ocr.js'), 'utf8');

function setup({failPage = false, failGlyphDecode = false} = {}) {
  const created = [];
  const parameters = [];
  const recognized = [];
  const canvases = [];
  const transforms = [];
  const context = vm.createContext({
    URL,
    Image: class {
      naturalWidth = 19;
      naturalHeight = 31;
      async decode() { if (failGlyphDecode) throw Error('glyph decode failed'); }
    },
    document: {baseURI: 'https://example.test/app/',
      createElement(tag) {
        assert.equal(tag, 'canvas');
        const canvas = {width: 0, height: 0, getContext: () => ({
          translate: (...args) => transforms.push(['translate', ...args]),
          rotate: angle => transforms.push(['rotate', angle]),
          drawImage: () => transforms.push(['draw']),
        })};
        canvases.push(canvas);
        return canvas;
      },
    },
    Tesseract: {
      async createWorker(language, _mode, options) {
        created.push({language, options});
        if (failPage && language.includes('+kor')) throw Error('page model unavailable');
        return {
          async setParameters(value) { parameters.push(value); },
          async recognize(input) {
            recognized.push(typeof input === 'string' ? input :
                {width: input.width, height: input.height});
            return {data: {text: language}};
          },
        };
      },
    },
  });
  vm.runInContext(source, context);
  return {recognize: context.jokboRecognize, glyph: context.jokboRecognizeGlyph, created, parameters, recognized, canvases, transforms};
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


test('glyph fallback restores vertical page mode for the next column', async () => {
  const {recognize, glyph, created, parameters} = setup();
  await glyph('single-glyph');
  await recognize('column', true);
  assert.equal(created.length, 1);
  assert.equal(parameters.at(-2).tessedit_pageseg_mode, '10');
  assert.equal(parameters.at(-1).tessedit_pageseg_mode, '5');
});

test('loopback service receives glyph bytes and shares capability lookup', async () => {
  const requests = [];
  const context = vm.createContext({
    URL, AbortSignal, location: {hostname:'127.0.0.1'},
    fetch: async (url, options) => {
      requests.push([url, options]);
      if (url === '/api/ocr/capabilities') {
        return {ok:true, json:async()=>({engine:'rapidocr'})};
      }
      if (url.startsWith('blob:')) return {ok:true, blob:async()=> 'image-bytes'};
      return {ok:true, json:async()=>({raw:'核'})};
    },
  });
  vm.runInContext(source, context);
  assert.equal(await context.jokboRecognizeGlyph('blob:crop'), '核');
  assert.equal(await context.jokboRecognize('blob:page'), '核');
  assert.equal(requests.filter(([url])=>url==='/api/ocr/capabilities').length, 1);
  assert.equal(requests.find(([url])=>url==='/api/ocr/glyph')[1].body, 'image-bytes');
});

test('a configured local engine error is shown to the user', async () => {
  const context = vm.createContext({
    URL, AbortSignal, location: {hostname:'127.0.0.1'},
    fetch: async url => {
      if (url === '/api/ocr/capabilities') return {ok:true,json:async()=>({engine:'rapidocr'})};
      if (url.startsWith('blob:')) return {ok:true,blob:async()=> 'image-bytes'};
      return {ok:false,json:async()=>({error:'model unavailable'})};
    },
  });
  vm.runInContext(source, context);
  await assert.rejects(context.jokboRecognizeGlyph('blob:crop'), /model unavailable/);
});

test('glyph model gets a complete counterclockwise raster and releases it', async () => {
  const {glyph, recognize, recognized, canvases, transforms} = setup();
  await glyph('glyph-image');
  assert.deepEqual(recognized[0], {width:31, height:19});
  assert.deepEqual(transforms.slice(0,2), [
    ['translate',0,19], ['rotate',-Math.PI/2],
  ]);
  assert.equal(canvases[0].width, 0);
  assert.equal(canvases[0].height, 0);
  await recognize('unchanged-column', true);
  assert.equal(recognized[1], 'unchanged-column');
  assert.equal(canvases.length, 1);
});

test('unreadable glyph does not block later column recognition', async () => {
  const {glyph, recognize, recognized} = setup({failGlyphDecode:true});
  await assert.rejects(glyph('bad-glyph'), /glyph decode failed/);
  assert.equal(await recognize('good-column', true), 'chi_tra_vert');
  assert.deepEqual(recognized, ['good-column']);
});
