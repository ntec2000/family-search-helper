const {chromium:pw}=require('playwright');
const path=require('node:path'),os=require('node:os');
const {spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
(async()=>{
 const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'jokbo-web-test-'));
 const server=spawn(process.env.PYTHON || 'python',[path.join(__dirname,'parser_engine.py')],{stdio:['ignore','pipe','inherit']});
 let browser;
 try{
  await new Promise((resolve,reject)=>{server.stdout.once('data',resolve);server.once('exit',code=>reject(Error('server '+code)));});
  browser=await pw.launch({executablePath:process.env.JOKBO_BROWSER_EXECUTABLE,args:["--no-sandbox","--disable-gpu","--disable-software-rasterizer","--no-zygote"],headless:true});
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  page.on('dialog',dialog=>dialog.accept());
  await page.route('**/ocr',r=>r.fulfill({json:{raw:'21世 諱 格\n22世 諱 核',candidates:[
   {generation:'21',name_hanja:'格',name_korean:'이격',birth_death:'',details:''},
   {generation:'22',name_hanja:'核',name_korean:'이핵',birth_death:'',details:''}]}}));
  await page.route('**/ocr/glyph',r=>r.fulfill({json:{raw:'核'}}));
  await page.goto('http://127.0.0.1:8765/');
  const png=await page.evaluate(()=>{
   const c=document.createElement('canvas');c.width=400;c.height=500;
   const x=c.getContext('2d');x.fillStyle='white';x.fillRect(0,0,400,500);x.fillStyle='black';x.fillRect(90,80,100,160);
   return c.toDataURL().split(',')[1];
  });
  await page.locator('#image').setInputFiles({name:'synthetic.png',mimeType:'image/png',buffer:Buffer.from(png,'base64')});
  await page.locator('#original').evaluate(im=>im.decode());
  await page.locator('#pick-glyph').click();
  await page.locator('#original').click({position:{x:50,y:50}});
  await page.locator('#original').click({position:{x:150,y:200}});
  await page.locator('#read-glyph').click();
  await page.waitForFunction(()=>document.querySelector('#glyph-result').value==='核');
  await page.locator('#scan').click();
  await page.waitForFunction(()=>document.querySelector('#rows').rows.length===2);
  const parentId=await page.locator('#rows tr').nth(1).locator('select option').nth(1).getAttribute('value');
  await page.locator('#rows tr').nth(1).locator('select').selectOption(parentId);
  assert.equal(await page.locator('#tree ul ul li').count(),1);
  await page.locator('#save').click();
  await page.reload();
  assert.equal(await page.locator('#rows tr').count(),2);
  assert.equal(await page.locator('#tree ul ul li').count(),1);
  const downloadPromise=page.waitForEvent('download');
  await page.locator('#export-backup').click();
  const download=await downloadPromise;
  await download.saveAs(path.join(temporary,'jokbo-e2e-backup.json'));
  const data=JSON.parse(fs.readFileSync(path.join(temporary,'jokbo-e2e-backup.json'),'utf8'));
  assert.equal(data.people[1].parentId,data.people[0].id);
  await page.locator('#rows tr').nth(1).locator('button').click();
  assert.equal(await page.locator('#rows tr').count(),1);
  await page.locator('#import-backup').setInputFiles(path.join(temporary,'jokbo-e2e-backup.json'));
  await page.waitForFunction(()=>document.querySelector('#rows').rows.length===2);
  assert.equal(await page.locator('#tree ul ul li').count(),1);
  await page.locator('#import-backup').setInputFiles({name:'bad.json',mimeType:'application/json',buffer:Buffer.from('{"people":[]}')});
  await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('복원 실패'));
  assert.equal(await page.locator('#rows tr').count(),2);
  await page.evaluate(()=>window.print=()=>{});
  await page.locator('#print-button').click();
  await page.emulateMedia({media:'print'});
  assert.equal(await page.locator('#print article').count(),2);
  await page.pdf({path:path.join(temporary,'jokbo-print-check.pdf'),preferCSSPageSize:true});
  await page.emulateMedia({media:'screen'});
  await page.screenshot({path:path.join(temporary,'jokbo-desktop-check.png'),fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('PASS Chromium image preview, glyph crop, mocked OCR, parent editing, save/reload, backup/download/restore, invalid backup, print PDF; zero page errors');
 }finally{if(browser)await browser.close();server.kill();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exit(1)});
