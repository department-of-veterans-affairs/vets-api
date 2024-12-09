import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';
import crypto from 'k6/crypto';
import encoding from 'k6/encoding';

// Add default config
const DEFAULT_CONFIG = {
  api_base_url: 'http://localhost:3000',
  client_id: 'load_test_client',
  redirect_uri: 'http://localhost:3000/v0/sign_in/callback',
  test_routes: [
    '/v0/user',
    '/v0/profile'
  ]
};

// Constants for rate limiting
const MIN_SLEEP = 1;  // minimum sleep in seconds
const MAX_SLEEP = 5;  // maximum sleep in seconds
const RATE_LIMIT_SLEEP = 60;  // sleep time when rate limited

// Constants for authentication
const AUTH_TYPES = {
  LOGINGOV: 'logingov',
  IDME: 'idme',
  DSLOGON: 'dslogon',
  MHV: 'mhv'
};

const SERVICE_LEVELS = {
  MIN: 'min',
  LOA1: 'loa1',
  LOA3: 'loa3',
  IAL1: 'ial1',
  IAL2: 'ial2'
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

// Add error rate metric
const errorRate = new Rate('errors');

// Update options for better control
export const options = {
  scenarios: {
    browser_flow: {
      executor: 'constant-arrival-rate',
      rate: 30,  // 30 iterations per minute
      timeUnit: '1m',
      duration: '5m',
      preAllocatedVUs: 1,
      maxVUs: 10,
      gracefulStop: '30s'
    }
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.01'],
    errors: ['rate<0.1']
  }
};

function handleRateLimit(response) {
  const retryAfter = response.headers['Retry-After'];
  if (retryAfter) {
    console.log(`Rate limited. Retry after: ${retryAfter} seconds`);
    sleep(parseInt(retryAfter));
  } else {
    console.log('Rate limited. Using default sleep time.');
    sleep(RATE_LIMIT_SLEEP);
  }
}

function extractAuthCodeFromHtml(html) {
  console.log('Attempting to extract auth code from HTML response...');
  
  // Look for redirect URL in the rendered HTML
  // The controller renders a redirect URL in the form:
  // window.location.href = 'http://localhost:3000/load_testing/callback?code=<auth_code>&type=logingov'
  const redirectMatch = html.match(/window\.location\.href\s*=\s*['"]([^'"]+)['"]/);
  if (redirectMatch) {
    const redirectUrl = redirectMatch[1];
    console.log('Found redirect URL:', redirectUrl);
    
    // Extract code from redirect URL
    const codeMatch = redirectUrl.match(/[?&]code=([^&]+)/);
    if (codeMatch) {
      return codeMatch[1];
    }
  }

  // Look for form with auth code
  // The controller might render a form with the code as a hidden input
  const formMatch = html.match(/<input[^>]+name="code"[^>]+value="([^"]+)"/);
  if (formMatch) {
    return formMatch[1];
  }

  // Look for error code
  const errorMatch = html.match(/[?&]code=([A-Z_]+)/);
  if (errorMatch) {
    console.error('Found error code:', errorMatch[1]);
    return null;
  }

  console.log('HTML snippet:', html.substring(0, 500));
  return null;
}

function extractRedirectUrl(html) {
  const metaRefreshMatch = html.match(/content="0;URL=([^"]+)"/);
  if (metaRefreshMatch) {
    return metaRefreshMatch[1].replace(/&amp;/g, '&');
  }
  return null;
}

function handleLoginGovForm(html) {
  console.log('Handling Login.gov form...');
  
  let currentResponse = null;  // Track the current response for cookies
  
  // First, check if we got a meta refresh
  const metaRefreshUrl = extractRedirectUrl(html);
  if (metaRefreshUrl) {
    console.log('Following meta refresh to:', metaRefreshUrl);
    currentResponse = http.get(metaRefreshUrl, {
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1'
      }
    });
    
    // Wait for page load
    sleep(1);
    html = currentResponse.body;
    console.log('Login page status:', currentResponse.status);
  }
  
  // Now look for the login form and required fields
  const formMatch = html.match(/<form[^>]+action="([^"]+)"[^>]*>/);
  const csrfMatch = html.match(/<input[^>]+name="authenticity_token"[^>]+value="([^"]+)"/);
  const requestIdMatch = html.match(/request_id=([^"&]+)/);
  
  if (!formMatch || !csrfMatch) {
    console.error('Could not find form or CSRF token in login page');
    console.log('Login page HTML snippet:', html.substring(0, 2000));
    return null;
  }

  // Make form action URL absolute
  let formAction = formMatch[1];
  if (formAction === '/') {
    formAction = 'https://idp.int.identitysandbox.gov/';
  } else if (formAction.startsWith('/')) {
    formAction = 'https://idp.int.identitysandbox.gov' + formAction;
  }
  const csrfToken = csrfMatch[1];
  const requestId = requestIdMatch ? requestIdMatch[1] : '';

  console.log('Found login form. Action:', formAction);
  console.log('Request ID:', requestId);
  console.log('CSRF Token:', csrfToken);

  // Log the form HTML for inspection
  console.log('Form HTML:', html.match(/<form[^>]+>[\s\S]*?<\/form>/)[0]);

  // Build form data string
  const formData = [
    `user[email]=${encodeURIComponent(__ENV.LOGIN_EMAIL || 'va.api.user+idme.001@gmail.com')}`,
    `user[password]=${encodeURIComponent(__ENV.LOGIN_PASSWORD || 'Password123!!!')}`,
    `authenticity_token=${encodeURIComponent(csrfToken)}`,
    'button=Sign+in',
    'commit=Sign+in',
    'platform_authenticator_available=id+platform_authenticator_available',
    `request_id=${encodeURIComponent(requestId)}`,
    'remember_device=false'
  ].join('&');

  console.log('Form data (without password):', formData.replace(/user\[password\]=[^&]+/, 'user[password]=REDACTED'));
  console.log('Submitting login form to:', formAction);
  const loginResponse = http.post(formAction, formData, {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Origin': 'https://idp.int.identitysandbox.gov',
      'Referer': metaRefreshUrl,
      'Cookie': currentResponse ? extractCookies(currentResponse) : '',
      'Host': 'idp.int.identitysandbox.gov',
      'Upgrade-Insecure-Requests': '1',
      'Accept-Language': 'en-US,en;q=0.5'
    },
    redirects: 0
  });

  console.log('Login form submission status:', loginResponse.status);
  console.log('Login response headers:', JSON.stringify(loginResponse.headers, null, 2));
  
  // Check for login error
  if (loginResponse.status === 200 && loginResponse.body.includes('usa-alert--error')) {
    console.error('Login failed: Invalid credentials');
    console.log('Login error page:', loginResponse.body.substring(0, 1000));
    // Log the error message
    const errorMatch = loginResponse.body.match(/<p class="usa-alert__text">([^<]+)<\/p>/);
    if (errorMatch) {
      console.error('Error message:', errorMatch[1]);
    }
    return null;
  }

  if (loginResponse.status === 302) {
    const location = loginResponse.headers['Location'];
    console.log('Login successful, following redirect:', location);
    return http.get(location, {
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Cookie': extractCookies(loginResponse)
      }
    });
  }

  return loginResponse;
}

// Add helper to extract request_id
function extractRequestId(html) {
  const match = html.match(/request_id=([^"&]+)/);
  return match ? match[1] : '';
}

// Helper function to extract cookies
function extractCookies(response) {
  const cookies = response.headers['Set-Cookie'];
  if (!cookies) return '';
  
  return Array.isArray(cookies) ? cookies.join('; ') : cookies;
}

function authorizeFlow(config) {
  console.log('Starting authorize flow...');
  const codeVerifier = '5787d673fb784c90f0e309883241803d';
  const state = generateRandomString();
  const nonce = generateRandomString();

  // Add random sleep to prevent rate limiting
  const sleepTime = Math.random() * (MAX_SLEEP - MIN_SLEEP) + MIN_SLEEP;
  sleep(sleepTime);

  const params = {
    client_id: config.client_id,
    response_type: 'code',
    type: AUTH_TYPES.LOGINGOV,
    code_challenge_method: 'S256',
    acr: SERVICE_LEVELS.MIN,
    code_challenge: '1BUpxy37SoIPmKw96wbd6MDcvayOYm3ptT-zbe6L_zM=',
    scope: 'openid profile email',
    state,
    nonce,
    redirect_uri: config.redirect_uri,
    operation: 'authorize'
  };

  console.log('Auth params:', params);

  const url = `${config.api_base_url}/v0/sign_in/authorize?${buildQueryString(params)}`;
  console.log('Authorize URL:', url);
  
  const authorizeResponse = http.get(url, {
    headers: {
      'Accept': 'text/html',
      'Content-Type': 'application/json'
    }
  });

  console.log('Authorize Response Status:', authorizeResponse.status);
  if (authorizeResponse.status !== 200) {
    console.error('Authorize Response Body:', authorizeResponse.body);
    return null;
  }

  if (authorizeResponse.status === 200) {
    console.log('Got 200 response, checking for redirect...');
    const redirectUrl = extractRedirectUrl(authorizeResponse.body);
    if (redirectUrl) {
      console.log('Found redirect URL:', redirectUrl);
      
      // Follow the redirect with rate limit handling
      console.log('Following redirect...');
      const redirectResponse = http.get(redirectUrl);
      console.log('Redirect Response Status:', redirectResponse.status);

      if (redirectResponse.status === 429) {
        handleRateLimit(redirectResponse);
        return null;
      }

      if (redirectResponse.status === 200) {
        // Handle Login.gov form
        const loginResponse = handleLoginGovForm(redirectResponse.body);
        if (loginResponse) {
          if (loginResponse.status === 302) {
            const location = loginResponse.headers['Location'];
            console.log('Login successful, following redirect:', location);
            const finalResponse = http.get(location, {
              headers: {
                'Accept': 'text/html'
              }
            });
            console.log('Final response status:', finalResponse.status);
            console.log('Final URL:', finalResponse.url);
            const code = extractCodeFromUrl(finalResponse.url);
            if (code) {
              console.log('Successfully extracted auth code');
              return { code, codeVerifier, state };
            }
          } else {
            console.error('Unexpected login response status:', loginResponse.status);
            console.log('Login response body:', loginResponse.body);
          }
        }
      }
    }
    console.log('HTML Response Body:', authorizeResponse.body.substring(0, 500));
  }

  return null;
}

function exchangeCodeForTokens(config, authResult) {
  console.log('Exchanging code for tokens...');
  
  const tokenResponse = http.post(
    `${config.api_base_url}/v0/sign_in/token`,
    JSON.stringify({
      grant_type: 'authorization_code',
      code: authResult.code,
      code_verifier: authResult.codeVerifier,
      client_id: config.client_id
    }),
    {
      headers: {
        'Content-Type': 'application/json'
      }
    }
  );

  console.log('Token exchange response:', tokenResponse.status);
  if (tokenResponse.status === 200) {
    return JSON.parse(tokenResponse.body);
  }

  console.error('Token exchange failed:', tokenResponse.body);
  return null;
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

function exchangeForVaGovTokens(config, tokens) {
  console.log('Starting VA.gov token exchange...');
  const payload = {
    grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
    subject_token: tokens.access_token,
    subject_token_type: 'urn:ietf:params:oauth:token-type:access_token',
    actor_token: tokens.device_secret,
    actor_token_type: 'urn:x-oath:params:oauth:token-type:device-secret',
    client_id: 'vaweb'
  };

  const response = http.post(
    `${config.api_base_url}/v0/sign_in/token`,
    JSON.stringify(payload),
    {
      headers: {
        'Content-Type': 'application/json'
      }
    }
  );

  console.log('VA.gov Token Exchange Status:', response.status);
  console.log('VA.gov Token Exchange Headers:', JSON.stringify(response.headers, null, 2));

  if (response.status === 200) {
    const cookies = extractCookies(response);
    console.log('Extracted Cookies:', JSON.stringify(cookies, null, 2));
    return cookies;
  }

  console.error('VA.gov Token Exchange Failed:', response.body);
  return null;
}

function refreshTokens(config, refreshToken) {
  const response = http.post(
    `${config.api_base_url}/v0/sign_in/refresh`,
    JSON.stringify({
      refresh_token: refreshToken
    }),
    {
      headers: {
        'Content-Type': 'application/json'
      }
    }
  );

  check(response, {
    'token refresh successful': (r) => r.status === 200
  });

  return extractCookies(response);
}

function testAuthenticatedRoute(config, cookies, route) {
  console.log(`Testing authenticated route: ${route}`);
  const response = http.get(
    `${config.api_base_url}${route}`,
    {
      headers: {
        'Cookie': `vagov_access_token=${cookies.access_token}; vagov_anti_csrf_token=${cookies.csrf_token}`,
        'X-CSRF-Token': cookies.csrf_token
      }
    }
  );

  console.log(`Route ${route} Response Status:`, response.status);
  console.log(`Route ${route} Response Body:`, response.body);

  check(response, {
    'authenticated route successful': (r) => r.status === 200
  });

  return response;
}

export default function(data) {
  console.log('\n--- Starting New Iteration ---');
  console.log('Data:', JSON.stringify(data, null, 2));
  
  // Get initial tokens
  const authResult = authorizeFlow(data.config);
  if (!authResult) {
    console.error('Authorization failed');
    return;
  }

  // Exchange code for tokens
  const tokens = exchangeCodeForTokens(data.config, authResult);
  if (!tokens) {
    console.error('Token exchange failed');
    return;
  }

  // Exchange for VA.gov tokens
  const cookies = exchangeForVaGovTokens(data.config, tokens);
  if (!cookies) {
    console.error('VA.gov token exchange failed');
    return;
  }

  // Test authenticated routes
  for (const route of DEFAULT_CONFIG.test_routes) {
    const response = testAuthenticatedRoute(data.config, cookies, route);
    if (response.status !== 200) {
      console.error(`Route ${route} test failed`);
    }
  }

  // Test token refresh if needed
  if (Math.random() < 0.1) {
    console.log('Testing token refresh...');
    const newCookies = refreshTokens(data.config, cookies.refresh_token);
    if (newCookies) {
      console.log('Token refresh successful');
    } else {
      console.error('Token refresh failed');
    }
  }

  sleep(1);
  console.log('--- Iteration Complete ---\n');
} 