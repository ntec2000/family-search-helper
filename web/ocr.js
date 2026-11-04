/* Tesseract.js 7.0.0 (Apache-2.0), local browser OCR; images never leave this browser. */
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
  let pending = Promise.resolve();
  globalThis.jokboRecognize = (path, singleColumn = false) => {
    const result = pending.then(async () => {
      const instance = await worker(singleColumn);
      const {data} = await instance.recognize(path);
      return data.text;
    });
    pending = result.catch(() => {});
    return result;
  };
})();
