import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../dist');
const port=Number(process.env.FRIDGE_WEB_PORT||4817);
const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.png':'image/png','.apk':'application/vnd.android.package-archive'};
const server=http.createServer((request,response)=>{
 if(!['GET','HEAD'].includes(request.method)){response.writeHead(405);response.end();return;}
 let file;
 try{file=path.resolve(root,'.'+decodeURIComponent(new URL(request.url,'http://localhost').pathname));}catch{response.writeHead(400);response.end();return;}
 if(file!==root&&!file.startsWith(root+path.sep)){response.writeHead(404);response.end();return;}
 try{if(fs.statSync(file).isDirectory())file=path.join(file,'index.html');}catch{response.writeHead(404);response.end();return;}
 if(!fs.existsSync(file)||!fs.statSync(file).isFile()){response.writeHead(404);response.end();return;}
 const size=fs.statSync(file).size;const extension=path.extname(file);
 const headers={'Content-Type':types[extension]||'application/octet-stream','Accept-Ranges':'bytes','Cache-Control':'no-cache'};
 if(extension==='.apk')headers['Content-Disposition']=`attachment; filename="${path.basename(file)}"`;
 let start=0,end=size-1,status=200;
 if(request.headers.range){
  const range=/^bytes=(\d*)-(\d*)$/.exec(request.headers.range);
  if(!range||(!range[1]&&!range[2])){response.writeHead(416,{'Content-Range':`bytes */${size}`});response.end();return;}
  if(!range[1])start=Math.max(0,size-Number(range[2]));
  else{start=Number(range[1]);if(range[2])end=Math.min(end,Number(range[2]));}
  if(start>end||start>=size){response.writeHead(416,{'Content-Range':`bytes */${size}`});response.end();return;}
  status=206;headers['Content-Range']=`bytes ${start}-${end}/${size}`;
 }
 headers['Content-Length']=end-start+1;response.writeHead(status,headers);
 if(request.method==='HEAD'){response.end();return;}
 const stream=fs.createReadStream(file,{start,end});stream.on('error',()=>response.destroy());response.on('close',()=>stream.destroy());stream.pipe(response);
});
server.listen(port,'127.0.0.1',()=>console.log(`Local: http://127.0.0.1:${port}/`));
process.on('SIGINT',()=>server.close(()=>process.exit(0)));
process.on('SIGTERM',()=>server.close(()=>process.exit(0)));
