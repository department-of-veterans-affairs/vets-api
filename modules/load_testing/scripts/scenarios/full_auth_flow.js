import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

export const options = {
  scenarios: {
    browser_flow: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 50 },  // Ramp up
        { duration: '5m', target: 50 },  // Stay steady
        { duration: '2m', target: 0 }    // Ramp down
      ],
      gracefulRampDown: '30s'
    },
    token_refresh: {
      executor: 'constant-vus',
      vus: 20,
      duration: '10m',
      startTime: '1m'
    }
  },
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.01']    // Less than 1% can fail
  }
};

export function setup() {
  // Create a new test session
  const payload = {
    concurrent_users: 100,
    configuration: {
      client_id: 'load_test_client',
      type: 'logingov',
      acr: 'http://idmanagement.gov/ns/assurance/ial/2',
      stages: [
        { duration: '2m', target: 50 },
        { duration: '5m', target: 100 },
        { duration: '2m', target: 0 }
      ]
    }
  };

  console.log('Creating test session with payload:', JSON.stringify(payload));
  
  const createResponse = http.post('http://localhost:3000/load_testing/v0/test_sessions', 
    JSON.stringify(payload),
    {
      headers: {
        'Content-Type': 'application/json',
      },
    }
  );
  
  console.log('Create Session Response:', createResponse.body);
  
  check(createResponse, {
    'test session created': (r) => r.status === 201,
  });
  
  if (createResponse.status !== 201) {
    throw new Error(`Failed to create test session: ${createResponse.status} ${createResponse.body}`);
  }
  
  const session = JSON.parse(createResponse.body);
  console.log('Session:', session);
  
  if (!session.id) {
    throw new Error('No session ID in response');
  }
  
  // Get test configuration
  const configResponse = http.get('http://localhost:3000/load_testing/v0/config');
  console.log('Config Response:', configResponse.body);
  
  check(configResponse, {
    'config retrieved': (r) => r.status === 200,
  });
  
  const config = JSON.parse(configResponse.body);
  
  return { 
    session_id: session.id,
    config: config 
  };
}

export default function(data) {
  if (!data.session_id) {
    console.error('No session ID available');
    return;
  }

  const flow = Math.random() < 0.7 ? 'authorize' : 'refresh';
  
  if (flow === 'authorize') {
    authorizeFlow(data.config);
  } else {
    refreshFlow(data.config, data.session_id);
  }
}

function authorizeFlow(config) {
  // Initial authorize call with PKCE
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = generateCodeChallenge(codeVerifier);
  
  const authorizeResponse = http.get(`${config.api_base_url}/v0/sign_in/authorize`, {
    params: {
      client_id: 'load_test_client',
      response_type: 'code',
      scope: 'openid profile email',
      state: generateRandomString(),
      nonce: generateRandomString(),
      type: 'logingov',
      acr: 'http://idmanagement.gov/ns/assurance/ial/2',
      code_challenge: codeChallenge,
      code_challenge_method: 'S256'
    }
  });

  check(authorizeResponse, {
    'authorize successful': (r) => r.status === 200
  });

  sleep(1);
}

function refreshFlow(config, session_id) {
  // Get a token from the test session
  const tokenResponse = http.get(`http://localhost:3000/load_testing/v0/test_sessions/${session_id}/tokens/next`);
  console.log('Token Response:', tokenResponse.body);
  
  check(tokenResponse, {
    'token retrieved': (r) => r.status === 200,
  });
  
  const token = JSON.parse(tokenResponse.body);

  // Token refresh
  const refreshResponse = http.post(`${config.api_base_url}/v0/sign_in/refresh`, {
    refresh_token: token.refresh_token,
    anti_csrf_token: token.device_secret
  });

  check(refreshResponse, {
    'refresh successful': (r) => r.status === 200
  });

  sleep(1);
}

// Helper functions for PKCE
function generateRandomString(length = 43) {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += charset.charAt(Math.floor(Math.random() * charset.length));
  }
  return result;
}

function generateCodeVerifier() {
  return generateRandomString();
}

function generateCodeChallenge(verifier) {
  // Note: In a real implementation, this would use SHA256
  // For testing purposes, we'll use the verifier as the challenge
  return verifier;
} 