import fs from 'node:fs';
import path from 'node:path';
const roots=['packages/domain/src','packages/application/src'];
const errors=[];
function scan(dir) { for(const entry of fs.readdirSync(dir,{withFileTypes:true})) { const p=path.join(dir,entry.name); if(entry.isDirectory())scan(p);else if(/\.tsx?$/.test(p)){const text=fs.readFileSync(p,'utf8');if(/from\s+['"](?:@tarojs|react)|\b(?:wx|Taro|my|tt)\./.test(text))errors.push(p);}}}
roots.forEach(scan);if(errors.length)throw new Error('Platform dependency in pure layer: '+errors.join(', '));
console.log('PASS domain/application platform boundaries');
