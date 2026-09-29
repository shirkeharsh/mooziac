import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = __dirname;
const PORT = 8080;

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

// Import Cloudflare Pages functions
let chatFunction;
let feedbackFunction;
let downloadAlertFunction;
try {
  const modChat = await import(path.join(ROOT_DIR, 'functions/api/chat.js'));
  chatFunction = modChat.onRequestPost;
  const modFeedback = await import(path.join(ROOT_DIR, 'functions/api/feedback.js'));
  feedbackFunction = modFeedback.onRequestPost;
  const modDl = await import(path.join(ROOT_DIR, 'functions/api/download-alert.js'));
  downloadAlertFunction = modDl.onRequestPost;
} catch (e) {
  console.error("Failed to load functions/api/*.js:", e);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Handle /api/chat
  if (url.pathname === '/api/chat' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', async () => {
      try {
        const jsonBody = JSON.parse(body || '{}');
        const fakeReq = {
          json: async () => jsonBody
        };
        const cfRes = await chatFunction({ request: fakeReq, env: {} });
        const data = await cfRes.json();
        res.writeHead(cfRes.status || 200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data));
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // Handle /api/feedback
  if (url.pathname === '/api/feedback' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', async () => {
      try {
        const jsonBody = JSON.parse(body || '{}');
        const fakeReq = {
          json: async () => jsonBody
        };
        const cfRes = await feedbackFunction({ request: fakeReq, env: {} });
        const data = await cfRes.json();
        res.writeHead(cfRes.status || 200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data));
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // Handle /api/download-alert
  if (url.pathname === '/api/download-alert' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', async () => {
      try {
        const jsonBody = JSON.parse(body || '{}');
        const fakeReq = {
          json: async () => jsonBody
        };
        const cfRes = await downloadAlertFunction({ request: fakeReq, env: {} });
        const data = await cfRes.json();
        res.writeHead(cfRes.status || 200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data));
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // Handle static files
  let filePath = path.join(ROOT_DIR, url.pathname === '/' ? 'index.html' : url.pathname);
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(ROOT_DIR, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found');
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content);
    }
  });
});

server.listen(PORT, () => {
  console.log(`\n==================================================`);
  console.log(`  🚀 Mooziac Local Web & AI Server Running!`);
  console.log(`  🌐 Website URL:  http://localhost:${PORT}`);
  console.log(`  💬 Support Page: http://localhost:${PORT}/support.html`);
  console.log(`  🤖 AI Endpoint:  http://localhost:${PORT}/api/chat`);
  console.log(`==================================================\n`);
  console.log(`Tip: Open http://localhost:${PORT}/support.html in your browser`);
  console.log(`and click the bottom-right chat bubble to test the AI bot!\n`);
});
