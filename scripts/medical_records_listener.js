#!/usr/bin/env node

/**
 * Medical Records FHIR Pagination Test Server
 * 
 * Following vets-api patterns for testing pagination retry logic:
 * - Runs on port 2004 (configured in settings.local.yml)
 * - ONLY intercepts paginated requests with '_getpage' parameter
 * - Proxies ALL other requests unchanged to port 2003 (AWS tunnel)
 * - Returns specific JSON files for matching pagination URLs
 */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const helmet = require('helmet');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 2004;
const PROXY_TARGET = 'https://localhost:2003';

// Configuration following vets-api environment variable patterns
const config = {
  logRequests: process.env.LOG_REQUESTS !== 'false',
};

// Security middleware following vets-api patterns
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging utility following vets-api logging patterns
const log = (level, message, data = {}) => {
  if (!config.logRequests && level === 'info') return;
  
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

// Handler for paginated requests only
const paginatedRequestHandler = (req, res, next) => {
  const isPaginatedRequest = req.url.includes('_getpage') || req.query._getpage;
  
  if (!isPaginatedRequest) {
    return next(); // Not paginated - pass through unchanged to AWS tunnel
  }

  log('info', `CAPTURED PAGINATED REQUEST: ${req.method} ${req.url}`, {
    query: req.query,
    userAgent: req.headers['user-agent'],
    hasAuth: !!req.headers.authorization,
  });

  // Check for specific pagination URL pattern for vitals next pages
  const vitalsPage1Pattern = /v1\/fhir\?_getpages=a97adfd5-4342-4406-b316-95dab282c425&_getpagesoffset=2&_count=2/;
  if (vitalsPage1Pattern.test(req.url)) {
    const jsonData = loadJsonFile('./mr/vitals_page_1.json');
    if (jsonData) {
      log('info', `RETURNING VITALS NEXT PAGE 1 JSON for: ${req.url}`);
      return res.status(200).json(jsonData);
    } else {
      log('error', `Failed to load vitals_page_1.json, falling back to proxy`);
    }
  }
  const vitalsPage2Pattern = /v1\/fhir\?_getpages=a97adfd5-4342-4406-b316-95dab282c425&_getpagesoffset=4&_count=2/;
  if (vitalsPage2Pattern.test(req.url)) {
    const jsonData = loadJsonFile('./mr/vitals_page_2.json');
    if (jsonData) {
      log('info', `RETURNING VITALS NEXT PAGE 2 JSON for: ${req.url}`);
      return res.status(200).json(jsonData);
    } else {
      log('error', `Failed to load vitals_page_2.json, falling back to proxy`);
    }
  }
  const vitalsPage3Pattern = /v1\/fhir\?_getpages=a97adfd5-4342-4406-b316-95dab282c425&_getpagesoffset=6&_count=2/;
  if (vitalsPage3Pattern.test(req.url)) {
    const jsonData = loadJsonFile('./mr/vitals_page_3.json');
    if (jsonData) {
      log('info', `RETURNING VITALS NEXT PAGE 3 JSON for: ${req.url}`);
      return res.status(200).json(jsonData);
    } else {
      log('error', `Failed to load vitals_page_3.json, falling back to proxy`);
    }
  }
  const vitalsPageLastPattern = /v1\/fhir\?_getpages=a97adfd5-4342-4406-b316-95dab282c425&_getpagesoffset=8&_count=2/;
  if (vitalsPageLastPattern.test(req.url)) {
    const jsonData = loadJsonFile('./mr/vitals_page_last.json');
    if (jsonData) {
      log('info', `RETURNING VITALS LAST PAGE JSON for: ${req.url}`);
      return res.status(200).json(jsonData);
    } else {
      log('error', `Failed to load vitals_page_last.json, falling back to proxy`);
    }
  }

  // Check for specific pagination URL pattern for vaccines next page
  const vaccinesNextPagePattern = /v1\/fhir\?_getpages=dcbf66e4-c2a6-4a70-880c-804cd3aab0a7&_getpagesoffset=2&_count=2/;
  if (vaccinesNextPagePattern.test(req.url)) {
    const jsonData = loadJsonFile('./mr/vaccines_next_page.json');
    if (jsonData) {
      log('info', `RETURNING VACCINES NEXT PAGE JSON for: ${req.url}`);
      return res.status(200).json(jsonData);
    } else {
      log('error', `Failed to load vaccines_next_page.json, falling back to proxy`);
    }
  }

  // Check for specific pagination URL pattern that should return 504 Gateway Timeout
  const gatewayTimeoutPattern = /v1\/fhir\?_getpages=182c0db7-a885-48da-94d8-d88e4175d0b1&_getpagesoffset=4&_count=2/;
  if (gatewayTimeoutPattern.test(req.url)) {
    log('warn', `RETURNING 504 GATEWAY TIMEOUT for: ${req.url}`);
    return res.status(504).json({
      error: 'Gateway Timeout',
      message: 'The server did not receive a timely response from the upstream server',
    });
  }

  // Continue to proxy unchanged
  next();
};

// Apply paginated request handler
app.use(paginatedRequestHandler);

// Proxy ALL requests unchanged to port 2003 (AWS tunnel)
const proxyOptions = {
  target: PROXY_TARGET,
  changeOrigin: true,
  secure: false,
  timeout: 30000,
  proxyTimeout: 30000,
  
  onProxyReq: (proxyReq, req) => {
    const isPaginated = req.url.includes('_getpage');
    if (isPaginated) {
      log('info', `PROXYING PAGINATED REQUEST UNCHANGED TO: ${PROXY_TARGET}${req.url}`);
    }
  },
  
  onProxyRes: (proxyRes, req, res) => {
    const isPaginated = req.url.includes('_getpage');
    
    if (isPaginated) {
      log('info', `PAGINATED RESPONSE: ${proxyRes.statusCode}`, {
        url: req.url,
        contentType: proxyRes.headers['content-type'],
      });
    }
    
    // Add debug headers following vets-api patterns
    res.setHeader('X-Proxy-Server', 'medical-records-listener');
    res.setHeader('X-Proxy-Target', PROXY_TARGET);
  },
  
  onError: (err, req, res) => {
    log('error', `PROXY ERROR for ${req.url}`, {
      error: err.message,
      target: PROXY_TARGET,
    });
    
    if (!res.headersSent) {
      res.status(502).json({
        error: 'Proxy Error',
        message: 'Failed to proxy request to AWS tunnel',
        target: PROXY_TARGET,
      });
    }
  },
};

// Apply proxy middleware to ALL routes
app.use('/', createProxyMiddleware(proxyOptions));

// Error handler following vets-api error handling patterns
app.use((err, req, res, next) => {
  log('error', `UNHANDLED ERROR for ${req.url}`, {
    error: err.message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  });
  
  if (!res.headersSent) {
    res.status(500).json({
      error: 'Internal Server Error',
      message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
    });
  }
});

// Graceful shutdown following vets-api patterns
const shutdown = (signal) => {
  log('info', `Received ${signal}, shutting down gracefully...`);
  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Start server
app.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════════════════════════════╗
║              Medical Records FHIR Pagination Test Server                 ║
╠═══════════════════════════════════════════════════════════════════════════╣
║ 🚀 Server: http://localhost:${PORT}                                      ║
║ 🔄 Proxy Target: ${PROXY_TARGET}                                         ║
║ 📊 Log Requests: ${config.logRequests ? 'ENABLED' : 'DISABLED'}          ║
╚═══════════════════════════════════════════════════════════════════════════╝

🎯 FUNCTIONALITY:
  • Intercepts ONLY paginated requests with '_getpage' parameter
  • Returns ./mr/vaccines_next_page.json for specific pagination URL
  • Returns 504 Gateway Timeout for specific error test pagination URL
  • Proxies ALL other requests UNCHANGED to port 2003 (AWS tunnel)

🧪 TESTING MODES:
  Normal mode (proxy everything unchanged):
    node scripts/medical_records_listener.js
    
  Quiet logging:
    LOG_REQUESTS=false node scripts/medical_records_listener.js

📄 SPECIAL RESPONSES:
  • URL containing 'v1/fhir?_getpages=a97adfd5-4342-4406-b316-95dab282c425&_getpagesoffset=2&_count=2'
    → Returns ./mr/vitals_page_1.json
  • URL containing 'v1/fhir?_getpages=a97adfd5-4342-4406-b316-95dab282c425&_getpagesoffset=4&_count=2'
    → Returns ./mr/vitals_page_2.json
  • URL containing 'v1/fhir?_getpages=a97adfd5-4342-4406-b316-95dab282c425&_getpagesoffset=6&_count=2'
    → Returns ./mr/vitals_page_3.json
  • URL containing 'v1/fhir?_getpages=a97adfd5-4342-4406-b316-95dab282c425&_getpagesoffset=56&_count=2'
    → Returns ./mr/vitals_page_last.json
  • URL containing 'v1/fhir?_getpages=dcbf66e4-c2a6-4a70-880c-804cd3aab0a7&_getpagesoffset=2'
    → Returns ./mr/vaccines_next_page.json
  • URL containing 'v1/fhir?_getpages=182c0db7-a885-48da-94d8-d88e4175d0
  `);
});

module.exports = { app, config };