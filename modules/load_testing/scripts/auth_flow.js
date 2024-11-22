import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 0 },   // Ramp down
  ],
};

export default function() {
  // Step 1: Initial authorize call
  let authorizeResponse = http.get('http://localhost:3000/v0/sign_in/authorize', {
    params: {
      client_id: 'test_client',
      response_type: 'code',
      scope: 'openid profile email',
      state: 'test_state',
      nonce: 'test_nonce',
    },
  });

  check(authorizeResponse, {
    'authorize successful': (r) => r.status === 200,
  });

  // Step 2: Exchange code for tokens
  let tokenResponse = http.post('http://localhost:3000/v0/sign_in/token', {
    grant_type: 'authorization_code',
    code: authorizeResponse.json('code'),
    client_id: 'test_client',
  });

  check(tokenResponse, {
    'token exchange successful': (r) => r.status === 200,
  });

  sleep(1);
} 