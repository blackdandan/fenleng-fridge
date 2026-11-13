const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=__dirname;
for(const file of ['index.html','terms/index.html','privacy/index.html','app/index.html']){
 const full=path.join(root,file),text=fs.readFileSync(full,'utf8');
 for(const match of text.matchAll(/(?:href|src)="([^"]+)"/g)){const ref=match[1];if(/^(#|mailto:|tel:|https?:)/.test(ref))continue;assert.ok(fs.existsSync(path.resolve(path.dirname(full),ref)),`${file}: missing ${ref}`);}
 assert.ok(text.includes('viewport'),`${file}: viewport`);
}
const legal=fs.readFileSync(path.join(root,'../shared/legal-content.js'),'utf8');const context={window:{}};vm.runInNewContext(legal,context);assert.ok(context.window.FRIDGE_LEGAL.terms.paragraphs.length>5);assert.equal(context.window.FRIDGE_LEGAL.terms.version,context.window.FRIDGE_LEGAL.privacy.version);
new vm.Script(fs.readFileSync(path.join(root,'legal.js'),'utf8'));
const home=fs.readFileSync(path.join(root,'index.html'),'utf8');assert.equal((home.match(/<button disabled>/g)||[]).length,2);assert.ok(home.includes('网站备案号待登记'));assert.ok(home.includes('APP 备案号待登记'));
for(const file of ['index.html','styles.css','legal.js'])assert.ok(!/fetch\(|XMLHttpRequest|https?:\/\//.test(fs.readFileSync(path.join(root,file),'utf8')),`external dependency ${file}`);
console.log('PASS website: local links, legal versions/content, viewport, unavailable downloads, filing placeholders, no network, script syntax');
