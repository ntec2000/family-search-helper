'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const canvas = $('canvas'), ctx = canvas.getContext('2d');
  let image = null, fileName = '', selection = null, origin = null, busy = false;
  let sourceRevision = 0, candidateResults = [], originalRaw = '';
  const status = msg => { $('status').textContent = msg; };
  const setBusy = value => { busy = value; $('read').disabled = value; $('parse').disabled = value; };
  function paint() {
    if (!image) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(image, 0, 0);
    if (selection) {
      const {x, y, w, h} = selection;
      ctx.fillStyle = 'rgba(20,140,210,.20)'; ctx.fillRect(x, y, w, h);
      ctx.strokeStyle = '#ffc447'; ctx.lineWidth = Math.max(2, canvas.width / 500);
      ctx.strokeRect(x, y, w, h);
    }
  }
  function point(event) {
    const rect = canvas.getBoundingClientRect();
    return {x: Math.max(0, Math.min(canvas.width, (event.clientX - rect.left) * canvas.width / rect.width)),
            y: Math.max(0, Math.min(canvas.height, (event.clientY - rect.top) * canvas.height / rect.height))};
  }
  canvas.addEventListener('pointerdown', e => {
    if (!image || busy) return;
    origin = point(e); canvas.setPointerCapture(e.pointerId);
  });
  canvas.addEventListener('pointermove', e => {
    if (!origin) return;
    const p = point(e);
    selection = {x: Math.min(p.x, origin.x), y: Math.min(p.y, origin.y),
      w: Math.abs(p.x - origin.x), h: Math.abs(p.y - origin.y)};
    paint();
  });
  canvas.addEventListener('pointerup', () => {
    if (!origin) return;
    origin = null;
    if (selection && (selection.w < 5 || selection.h < 5)) selection = null;
    paint();
  });
  canvas.addEventListener('pointercancel', () => { origin = null; selection = null; paint(); });
  $('reset').addEventListener('click', () => { selection = null; paint(); status('전체 이미지가 선택되었습니다.'); });
  $('file').addEventListener('change', async e => {
    const file = e.target.files[0]; e.target.value = '';
    if (!file) return;
    if (busy) { status('판독이 끝난 후 이미지를 변경해 주세요.'); return; }
    if ((originalRaw || $('edited').value) && !confirm('새 이미지를 열면 현재 화면의 원문과 후보가 지워집니다. 필요한 경우 먼저 JSON으로 저장해 주세요. 계속하시겠습니까?')) return;
    if (!['image/jpeg','image/png'].includes(file.type) || file.size > 12 * 1024 * 1024) {
      status('12 MiB 이하 JPG 또는 PNG 이미지를 선택해 주세요.'); return;
    }
    const revision = ++sourceRevision;
    const url = URL.createObjectURL(file), next = new Image();
    next.onload = () => {
      URL.revokeObjectURL(url);
      if (revision !== sourceRevision) return;
      image = next; fileName = file.name; selection = null; originalRaw = ''; candidateResults = [];
      $('raw').value = ''; $('edited').value = ''; showCandidates();
      canvas.width = next.naturalWidth; canvas.height = next.naturalHeight;
      $('empty').hidden = true; canvas.hidden = false; paint();
      status('이미지를 열었습니다. 판독할 영역을 선택하세요.');
    };
    next.onerror = () => { URL.revokeObjectURL(url); status('이미지를 읽지 못했습니다.'); };
    next.src = url;
  });
  function showCandidates() {
    const target = $('candidates'); target.replaceChildren();
    $('count').textContent = candidateResults.length + '건';
    if (!candidateResults.length) { target.textContent = '표시할 인물 후보가 없습니다. 원문을 직접 확인하세요.'; return; }
    candidateResults.forEach((p, i) => {
      const row = document.createElement('div'); row.className = 'candidate';
      const name = [p.name_korean, p.name_hanja].filter(Boolean).join(' ') || '이름 미상';
      row.textContent = (i + 1) + '. ' + name + ' · ' + (p.relation || '인물 후보') +
        (p.generation ? ' · ' + p.generation + '세 후보' : '') +
        (p.birth_death ? '\n생몰 원문: ' + p.birth_death : '') +
        (p.details ? '\n참고 원문: ' + p.details : '') + '\n검토 필요';
      target.appendChild(row);
    });
  }
  async function request(path, options) {
    const response = await fetch(path, options);
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || '요청에 실패했습니다.');
    return result;
  }
  $('read').addEventListener('click', async () => {
    if (!image || busy) { status('먼저 이미지를 선택해 주세요.'); return; }
    if ((originalRaw || $('edited').value) && !confirm('다시 판독하면 현재 화면의 원문과 후보가 바뀝니다. 필요한 경우 먼저 JSON으로 저장해 주세요. 계속하시겠습니까?')) return;
    setBusy(true); status('로컬 OCR 판독 중입니다. 잠시 기다려 주세요.');
    try {
      const area = selection || {x:0,y:0,w:canvas.width,h:canvas.height};
      const crop = document.createElement('canvas');
      crop.width = Math.max(1, Math.round(area.w)); crop.height = Math.max(1, Math.round(area.h));
      crop.getContext('2d').drawImage(image, area.x, area.y, area.w, area.h, 0, 0, crop.width, crop.height);
      const blob = await new Promise(resolve => crop.toBlob(resolve, 'image/png'));
      if (!blob || blob.size > 12 * 1024 * 1024) throw new Error('선택 영역이 너무 큽니다. 더 작은 영역을 선택하세요.');
      const result = await request('/ocr', {method:'POST', body:blob,
        headers:{'X-Jokbo-Surname':encodeURIComponent($('surname').value.trim())}});
      originalRaw = result.raw; $('raw').value = originalRaw; $('edited').value = originalRaw;
      candidateResults = result.candidates; showCandidates();
      status('판독 완료: 원문과 후보를 대조해 주세요.');
    } catch (error) { status('판독 실패: ' + error.message); }
    finally { setBusy(false); }
  });
  $('parse').addEventListener('click', async () => {
    if (busy || !$('edited').value.trim()) { status('검토할 원문을 입력해 주세요.'); return; }
    setBusy(true);
    try {
      const result = await request('/parse', {method:'POST', headers:{'Content-Type':'application/json'},
        body:JSON.stringify({raw:$('edited').value, surname:$('surname').value.trim()})});
      candidateResults = result.candidates; showCandidates();
      status('후보를 다시 찾았습니다. OCR 원문은 그대로 보존했습니다.');
    } catch(error) { status('후보 분석 실패: ' + error.message); }
    finally { setBusy(false); }
  });
  $('save').addEventListener('click', () => {
    if (!originalRaw && !$('edited').value.trim()) { status('저장할 원문이 없습니다.'); return; }
    const data = {format:'family-history-ocr-review-v1', source_file:fileName,
      ocr_original:originalRaw, reviewed_text:$('edited').value, candidates:candidateResults};
    const url = URL.createObjectURL(new Blob([JSON.stringify(data,null,2)], {type:'application/json'}));
    const link = document.createElement('a'); link.href = url; link.download = '족보_OCR_검토.json';
    document.body.appendChild(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
    status('검토 JSON 저장을 요청했습니다. 이미지 원본은 별도로 보관해 주세요.');
  });
})();
