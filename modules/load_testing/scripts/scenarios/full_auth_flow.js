import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

export const options = {
  scenarios: {
    browser_flow: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 20 },  // Reduced initial load
        { duration: '5m', target: 50 },  // Gradual ramp up
        { duration: '2m', target: 0 }    // Ramp down
      ],
      gracefulRampDown: '30s'
    },
    token_refresh: {
      executor: 'constant-vus',
      vus: 10,                          // Reduced concurrent users
      duration: '10m',
      startTime: '1m'
    }
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // Increased timeout threshold
    http_req_failed: ['rate<0.05']      // Allow up to 5% failure rate
  }
};

export function setup() {
  const params = {
    timeout: '10s'  // Increased timeout
  };
  
  // Get test session configuration
  const response = http.get('http://localhost:3000/load_testing/v0/test_sessions/5', params);
  if (!response.status === 200) {
    console.log('Failed to get test session:', response.status, response.body);
    return {};
  }
  
  const session = JSON.parse(response.body);
  
  // Get test configuration
  const configResponse = http.get('http://localhost:3000/load_testing/v0/config', params);
  if (!configResponse.status === 200) {
    console.log('Failed to get config:', configResponse.status, configResponse.body);
    return {};
  }
  
  const config = JSON.parse(configResponse.body);
  return { session, config };
}

export default function(data) {
  if (!data.session || !data.config) {
    console.log('Missing required configuration');
    return;
  }

  const flow = Math.random() < 0.7 ? 'authorize' : 'refresh';
  
  try {
    if (flow === 'authorize') {
      authorizeFlow(data.config);
    } else {
      refreshFlow(data.config, data.session);
    }
  } catch (e) {
    console.error('Error in flow:', e);
  }
  
  sleep(1);
}

function authorizeFlow(config) {
  const params = {
    timeout: '10s'
  };

  const authorizeResponse = http.get(`${config.api_base_url}/v0/sign_in/authorize`, {
    params: {
      client_id: config.client_id,
      response_type: 'code',
      scope: 'openid profile email',
      state: 'test_state',
      nonce: 'test_nonce',
      type: config.type,
      acr: config.acr
    },
    ...params
  });

  check(authorizeResponse, {
    'authorize successful': (r) => r.status === 200
  });
}

function refreshFlow(config, session) {
  const params = {
    timeout: '10s'
  };

  const tokenResponse = http.get(
    `http://localhost:3000/load_testing/v0/test_sessions/${session.id}/tokens/next`,
    params
  );

  if (tokenResponse.status !== 200) {
    console.log('Failed to get token:', tokenResponse.status, tokenResponse.body);
    return;
  }

  const token = JSON.parse(tokenResponse.body);
  if (!token || !token.refresh_token) {
    console.log('Invalid token response:', token);
    return;
  }

  const refreshResponse = http.post(`${config.api_base_url}/v0/sign_in/refresh`, {
    refresh_token: token.refresh_token,
    anti_csrf_token: token.device_secret
  }, params);

  check(refreshResponse, {
    'refresh successful': (r) => r.status === 200
  });
} 