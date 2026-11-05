/* Browser Tesseract or a same-origin loopback RapidOCR service. */
(() => {
  const version = '7.0.0';
  const cdn = 'https://cdn.jsdelivr.net/npm/';
  let enginePromise;
  const workers = new Map();

  function loadEngine() {
    if (globalThis.Tesseract) return Promise.resolve();
    enginePromise ??= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = `${cdn}tesseract.js@${version}/dist/tesseract.min.js`;
      script.onload = resolve;
      script.onerror = () => {
        script.remove();
        reject(new Error('OCR 엔진을 받지 못했습니다. 인터넷 연결을 확인하세요.'));
      };
      document.head.appendChild(script);
    }).catch(error => { enginePromise = null; throw error; });
    return enginePromise;
  }

  function worker(singleColumn) {
    if (!workers.has(singleColumn)) {
      const initializing = (async () => {
        await loadEngine();
        const instance = await globalThis.Tesseract.createWorker(
          singleColumn ? 'chi_tra_vert' : 'chi_tra_vert+kor', 1, {
            workerPath: `${cdn}tesseract.js@${version}/dist/worker.min.js`,
            corePath: `${cdn}tesseract.js-core@${version}`,
            ...(singleColumn
              ? {langPath: new URL('ocr-models/', document.baseURI).href,
                 gzip: false, cachePath: 'jokbo-best-v1'}
              : {langPath: 'https://tessdata.projectnaptha.com/4.0.0'}),
          });
        try {
          await instance.setParameters({tessedit_pageseg_mode: '5', preserve_interword_spaces: '1'});
          return instance;
        } catch (error) {
          await instance.terminate();
          throw error;
        }
      })().catch(error => { workers.delete(singleColumn); throw error; });
      workers.set(singleColumn, initializing);
    }
    return workers.get(singleColumn);
  }

  let servicePromise;
  async function localService() {
    if (!['127.0.0.1', 'localhost'].includes(globalThis.location?.hostname)) return null;
    servicePromise ??= fetch('/api/ocr/capabilities', {
      signal: AbortSignal.timeout(1500),
    }).then(async response => {
      if (!response.ok) return null;
      const data = await response.json();
      return data.engine === 'rapidocr' ? data : null;
    }).catch(() => null);
    return servicePromise;
  }

  let pending = Promise.resolve();
  function recognize(path, singleColumn, glyph) {
    const result = pending.then(async () => {
      const service = await localService();
      if (service) {
        const image = await fetch(path);
        if (!image.ok) throw new Error('선택한 이미지 영역을 읽지 못했습니다.');
        const response = await fetch(glyph ? '/api/ocr/glyph' : '/api/ocr', {
          method: 'POST',
          body: await image.blob(),
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'PC 한자 판독에 실패했습니다.');
        if (typeof data.raw !== 'string') throw new Error('판독 응답 형식이 올바르지 않습니다.');
        return data.raw;
      }
      const instance = await worker(singleColumn || glyph);
      await instance.setParameters({
        tessedit_pageseg_mode: glyph ? '10' : '5',
        preserve_interword_spaces: '1',
      });
      const {data} = await instance.recognize(path);
      return data.text;
    });
    pending = result.catch(() => {});
    return result;
  }
  globalThis.jokboRecognize = (path, singleColumn = false) =>
    recognize(path, singleColumn, false);
  globalThis.jokboRecognizeGlyph = path => recognize(path, true, true);
})();
