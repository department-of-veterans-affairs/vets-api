import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';
import crypto from 'k6/crypto';
import encoding from 'k6/encoding';

// Add default config
const DEFAULT_CONFIG = {
  api_base_url: 'http://localhost:3000',
  client_id: 'vaweb_api_load_testing'
};

// Helper functions
function generateRandomString(length = 32) {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  const bytes = crypto.randomBytes(length);
  for (let i = 0; i < length; i++) {
    result += charset.charAt(bytes[i] % charset.length);
  }
  return result;
}

function base64URLEncode(str) {
  return str.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function buildQueryString(params) {
  return Object.entries(params)
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
    .join('&');
}

function extractCodeFromUrl(url) {
  if (!url) return null;
  const match = url.match(/code=([^&]+)/);
  return match ? match[1] : null;
}

export const options = {
  scenarios: {
    browser_flow: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 10 },
        { duration: '3m', target: 10 },
        { duration: '1m', target: 0 }
      ],
      gracefulRampDown: '30s'
    }
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.01']
  }
};

function authorizeFlow(config) {
  // Use fixed values from ticket
  const codeVerifier = '5787d673fb784c90f0e309883241803d';
  const state = generateRandomString();
  const nonce = generateRandomString();

  const params = {
    client_id: 'vaweb_api_load_testing',
    response_type: 'code',
    type: 'logingov',
    code_challenge_method: 'S256',
    acr: 'min',
    code_challenge: '1BUpxy37SoIPmKw96wbd6MDcvayOYm3ptT-zbe6L_zM=',
    scope: 'openid profile email device_sso',
    state,
    nonce,
    redirect_uri: 'http://localhost:3000/load_testing/callback'
  };

  const url = `${config.api_base_url}/v0/sign_in/authorize?${buildQueryString(params)}`;
  console.log('Authorize URL:', url);
  
  const authorizeResponse = http.get(url, {
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    }
  });

  check(authorizeResponse, {
    'authorize successful': (r) => r.status === 200 || r.status === 302
  });

  if (authorizeResponse.status === 302) {
    const location = authorizeResponse.headers['Location'];
    console.log('Redirect Location:', location);
    const code = extractCodeFromUrl(location);
    if (code) {
      return exchangeCodeForTokens(config, code, codeVerifier);
    }
  }

  return null;
}

function exchangeCodeForTokens(config, code, codeVerifier) {
  const tokenResponse = http.post(
    `${config.api_base_url}/v0/sign_in/token`,
    JSON.stringify({
      grant_type: 'authorization_code',
      code_verifier: codeVerifier,
      code: code
    }),
    {
      headers: {
        'Content-Type': 'application/json'
      }
    }
  );

  check(tokenResponse, {
    'token exchange successful': (r) => r.status === 200
  });

  return tokenResponse.status === 200 ? JSON.parse(tokenResponse.body) : null;
}

export function setup() {
  console.log('Starting setup...');
  
  const payload = {
    concurrent_users: 100,
    configuration: {
      client_id: 'vaweb_api_load_testing',
      type: 'logingov',
      acr_values: 'min',
      stages: [
        { duration: '1m', target: 10 },
        { duration: '3m', target: 10 },
        { duration: '1m', target: 0 }
      ]
    }
  };

  console.log('Creating test session...');
  const createResponse = http.post(
    `${DEFAULT_CONFIG.api_base_url}/load_testing/v0/test_sessions`,
    JSON.stringify(payload),
    {
      headers: {
        'Content-Type': 'application/json',
      },
    }
  );

  console.log('Test session response:', createResponse.status, createResponse.body);

  if (createResponse.status !== 201) {
    console.error('Failed to create test session:', createResponse.body);
    return { config: DEFAULT_CONFIG };
  }

  const session = JSON.parse(createResponse.body);
  console.log('Session created:', session.id);

  return {
    config: DEFAULT_CONFIG,
    session_id: session.id
  };
}

export default function(data) {
  console.log('Starting iteration with data:', JSON.stringify(data));
  const result = authorizeFlow(data.config);
  if (result) {
    console.log('Authorization successful:', result);
  }
  sleep(1);
} 