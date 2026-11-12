const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
http.createServer((req,res)=>{
  let route;try{route=decodeURIComponent(req.url.split('?')[0]);}catch{res.writeHead(400);res.end('Bad request');return;}
  if(route==='/')route='/mvp/index.html';else if(!route.startsWith('/shared/')&&!route.startsWith('/mvp/'))route='/mvp'+route;
  const file=path.resolve(root,'.'+route);
  if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  fs.readFile(file,(error,data)=>{if(error){res.writeHead(404);res.end('Not found');return;}res.setHeader('Content-Type',({'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.png':'image/png'})[path.extname(file)]||'application/octet-stream');res.end(data);});
}).listen(4173,'127.0.0.1',()=>console.log('Local: http://127.0.0.1:4173'));
