const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
http.createServer((req, res) => {
  let file;
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    file = path.resolve(root, '.' + (pathname === '/' ? '/website/' : pathname));
    if (file !== root && !file.startsWith(root + path.sep)) throw new Error('outside root');
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  } catch { res.writeHead(400); return res.end('Invalid path'); }
  fs.readFile(file, (error, body) => {
    if (error) { res.writeHead(404); return res.end('Not found'); }
    res.setHeader('Content-Type', ({ '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml' })[path.extname(file)] || 'application/octet-stream');
    res.end(body);
  });
}).listen(4180, '127.0.0.1', () => console.log('Local: http://127.0.0.1:4180/website/ | App: http://127.0.0.1:4180/mvp/'));
