/* Tesseract.js 6.0.1 (Apache-2.0), local browser OCR; images never leave this browser. */
(() => {
  let workerPromise;
  let columnWorkerPromise;
  async function worker(singleColumn) {
    if (singleColumn && columnWorkerPromise) return columnWorkerPromise;
    if (!workerPromise) {
      workerPromise = (async () => {
        if (!globalThis.Tesseract) {
          await new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/tesseract.min.js';
            script.onload = resolve;
            script.onerror = () => reject(new Error('OCR 엔진을 받지 못했습니다. 인터넷 연결을 확인하세요.'));
            document.head.appendChild(script);
          });
        }
        const instance = await Tesseract.createWorker('chi_tra_vert+kor', 1, {
          workerPath: 'https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/worker.min.js',
          corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@6.0.0',
          langPath: 'https://tessdata.projectnaptha.com/4.0.0',
        });
        await instance.setParameters({tessedit_pageseg_mode: '5', preserve_interword_spaces: '1'});
        return instance;
      })().catch(error => { workerPromise = null; throw error; });
    }
    if (!singleColumn) return workerPromise;
    columnWorkerPromise = (async () => {
      await workerPromise;
      const instance = await Tesseract.createWorker('chi_tra_vert', 1, {
        workerPath: 'https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/worker.min.js',
        corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@6.0.0',
        langPath: new URL('ocr-models/', document.baseURI).href,
        gzip: false, cachePath: 'jokbo-best-v1',
      });
      await instance.setParameters({tessedit_pageseg_mode: '5', preserve_interword_spaces: '1'});
      return instance;
    })().catch(error => { columnWorkerPromise = null; throw error; });
    return columnWorkerPromise;
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
