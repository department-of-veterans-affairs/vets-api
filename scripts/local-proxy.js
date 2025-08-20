// proxy-server.js
const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");

const PORT = 2004;
const TARGET_PORT = 2003;

// Logging utility following vets-api logging patterns
const log = (level, message, data = {}) => {
  const timestamp = new Date().toISOString();
  const logData = Object.keys(data).length > 0 ? JSON.stringify(data, null, 2) : '';
  console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}${logData ? '\n' + logData : ''}`);
};

// Helper function to load JSON file
const loadJsonFile = (filePath) => {
  try {
    const fullPath = path.join(__dirname, '..', filePath);
    const jsonContent = fs.readFileSync(fullPath, 'utf8');
    return JSON.parse(jsonContent);
  } catch (error) {
    log('error', `Failed to load JSON file: ${filePath}`, { error: error.message });
    return null;
  }
};

const server = http.createServer((req, res) => {
  console.log(`Incoming request: ${req.method} ${req.url}`);


  if (req.url.includes("_getpages=a97adfd5-4342-4406-b316-95dab282c425") || req.url.includes("/v1/fhir/Observation") ) {
    // Check for specific pagination URL pattern for Vitals
    const vitalsPage1Pattern = /v1\/fhir\/Observation/;
    if (vitalsPage1Pattern.test(req.url)) {
        const jsonData = loadJsonFile('./scripts/mr/vitals_page_1.json');
        if (jsonData) {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(jsonData));
            return;
        } else {
            log('error', `Failed to load vitals_page_1.json, falling back to proxy`);
        }
    }
    // Iterate through pages 2-5
    for (let pageNum = 2; pageNum <= 5; pageNum++) {
        const pagePattern = new RegExp(`&_getpagesoffset=${(pageNum-1)*2}&_count=2`);
        console.log(`Iterate through pages: ${pagePattern}`);
        if (pagePattern.test(req.url)) {
            const jsonData = loadJsonFile(`./scripts/mr/vitals_page_${pageNum}.json`);
            if (jsonData) {
                log('info', `RETURNING VITALS PAGE ${pageNum} JSON for: ${req.url}`);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify(jsonData));
                return;
            } else {
                log('error', `Failed to load vitals_page_${pageNum}.json, falling back to proxy`);
            }
        }
    }
    //  res.writeHead(400, { "Content-Type": "text/plain" });
    //  res.end();
    res.writeHead(500, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
      error: 'Internal Server Error', 
      message: 'Simulated server error for pagination testing'
    }));
    return; // stop here, don't proxy
  }
  const options = {
    hostname: "localhost",
    port: TARGET_PORT,
    path: req.url,
    method: req.method,
    headers: req.headers,
    rejectUnauthorized: false, // if using self-signed certs, disable verification
  };

  const proxy = https.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxy.on("error", (err) => {
    console.error(`Proxy error: ${err.message}`);
    res.writeHead(502);
    res.end("Bad gateway");
  });

  req.pipe(proxy, { end: true });
});

server.listen(PORT, () => {
  console.log(
    `Proxy server listening on http://localhost:${PORT}, forwarding to https://localhost:${TARGET_PORT}`
  );
});