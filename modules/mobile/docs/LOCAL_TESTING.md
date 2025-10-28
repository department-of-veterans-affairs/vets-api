# Local Testing with Mobile API Endpoints

This guide explains how to test mobile API endpoints locally without needing the mobile app.

## Quick Start

Generate a JWT token for testing:

```bash
# Generate a new local token
bundle exec rake mobile:generate_token

# Or import a staging bearer token (recommended if you have one)
bundle exec rake mobile:import_staging_token token='YOUR_STAGING_BEARER_TOKEN' mhv_id=YOUR_MHV_ID
```

This will output a JWT token that you can use with Postman, curl, or any HTTP client.

## Using the Token

### In Postman

1. Create a new request to `http://localhost:3000/mobile/v0/user` (or any mobile endpoint)
2. Set these headers:
   - **Authorization**: `Bearer <your-jwt-token>`
   - **Authentication-Method**: `SIS`
   - **X-Key-Inflection**: `camel` (for camelCase responses)

### With curl

```bash
curl -H 'Authorization: Bearer <your-jwt-token>' \
     -H 'Authentication-Method: SIS' \
     -H 'X-Key-Inflection: camel' \
     http://localhost:3000/mobile/v0/user
```

## Using a Staging Bearer Token (Recommended)

If you already have a staging bearer token (from the mobile app or staging environment), you can import it to create a local token with the same user data:

```bash
# Import your staging token
bundle exec rake mobile:import_staging_token token='YOUR_STAGING_BEARER_TOKEN' mhv_id=YOUR_MHV_ID
```

**What this does:**
1. Decodes your staging token to extract user information
2. Creates local user records matching the staging user
3. Generates a **new** local token (signed with local key) representing the same user
4. You can then use the new local token with your local vets-api

**Why this is better:**
- Uses real user data from staging (name, email, etc.)
- Works with the correct MHV ID from staging
- The new token works locally (signed with local key)
- Easier than manually specifying all user details

```bash
# Example with MHV ID
bundle exec rake mobile:import_staging_token \
  token='eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOi...' \
  mhv_id=12345678
```

## Customizing the Token

You can customize the user details and token duration:

```bash
# Custom user details
bundle exec rake mobile:generate_token first_name=Jane last_name=Doe

# Custom ICN
bundle exec rake mobile:generate_token icn=1234567890V123456

# Custom email
bundle exec rake mobile:generate_token email=custom@example.com

# Custom token duration (in minutes, default is 30)
bundle exec rake mobile:generate_token duration=60

# Combine multiple options
bundle exec rake mobile:generate_token first_name=John last_name=Smith icn=9876543210V654321 duration=120
```

## How It Works

The mobile app supports two authentication methods:

1. **IAM Authentication** (legacy) - Requires introspection with external IAM service
2. **SIS Authentication** (modern) - Uses locally-signed JWT tokens

By including the `Authentication-Method: SIS` header, you're telling the mobile controllers to use the Sign-In Service (SIS) authentication flow, which validates tokens locally without external service calls.

The rake task creates:
- A `UserAccount` record with the specified ICN
- A `UserVerification` record
- An `OAuthSession` for the mobile client
- A signed JWT `AccessToken` valid for the specified duration

## Cleanup

When you're done testing, clean up the test data:

```bash
bundle exec rake mobile:cleanup_test_data
```

This removes:
- All OAuth sessions for the vamobile client
- Orphaned user accounts (those without verifications)

## Troubleshooting

### "Access token JWT is malformed"

Make sure you're including the `Authentication-Method: SIS` header. Without it, the mobile app tries to use IAM authentication which requires a different token format.

### "Access token body does not match signature"

This error was caused by including `user_attributes` in the JWT when the vamobile client config doesn't support them. This has been fixed in the latest version of the rake task. If you still see this error:

1. Make sure you're running the latest version of the rake task
2. Clean up old data: `bundle exec rake mobile:cleanup_test_data`
3. Generate a new token: `bundle exec rake mobile:generate_token`

The token should now have `"user_attributes":null` which matches the client configuration.

### Token expired

Tokens expire after 30 minutes by default. Generate a new one with:

```bash
bundle exec rake mobile:generate_token
```

Or create a longer-lived token:

```bash
bundle exec rake mobile:generate_token duration=120  # 2 hours
```

### External service errors (Lighthouse, MVI, etc.)

If you get errors like "Invalid authentication credentials" from Lighthouse Facilities or other external services, this is expected when testing locally. The authentication is working correctly, but the endpoint is trying to fetch data from external services that aren't configured for local development.

These errors indicate your token is valid and the mobile API authenticated you successfully. To test with real data, use the MHV staging setup (see [MHV_STAGING_SETUP.md](MHV_STAGING_SETUP.md)).

### "Validation failed: Icn has already been taken"

This happens if you're specifying a custom ICN that already exists. Either:
1. Use a different ICN
2. Run cleanup first: `bundle exec rake mobile:cleanup_test_data`
3. Let the script generate a random ICN (don't specify the `icn` parameter)

## Testing Different Scenarios

### Test with a specific ICN

Some endpoints require specific test data. You can target a specific test user:

```bash
bundle exec rake mobile:generate_token icn=1008596379V859838
```

### Test token expiration

Create a token that expires quickly to test expiration handling:

```bash
bundle exec rake mobile:generate_token duration=1  # Expires in 1 minute
```

## Getting a Staging Bearer Token

To get a staging bearer token from the mobile app or staging website:

1. **From mobile app**: Use the app's debug mode or network inspector to capture the bearer token from the Authorization header
2. **From staging website**: 
   - Visit https://staging.va.gov and sign in
   - Open browser DevTools → Network tab
   - Make an API request
   - Find the Authorization header with the Bearer token
3. **From another developer**: Ask a team member who has already authenticated

Once you have the token, import it:

```bash
bundle exec rake mobile:import_staging_token token='YOUR_TOKEN' mhv_id=YOUR_MHV_ID
```

## Finding Your Staging MHV ID

If you have a list of actual MHV IDs for staging users, you can use them when generating tokens:

```bash
# Generate token with your actual staging MHV ID
bundle exec rake mobile:generate_mhv_token user_number=81 mhv_id=YOUR_ACTUAL_MHV_ID
```

**Where to get MHV IDs:**

1. **From your team** - Ask for the staging MHV ID list
2. **From MVI staging CSV** - Check `va.gov-team-sensitive/Administrative/vagov-users/mvi-staging-users.csv`
3. **From staging database** - Query MPI/MVI staging for the ICN's MHV correlation ID
4. **From logs** - Look for `mhv_id` in the error message when you get "SM ACCESS DENIED"

The MHV ID shown in the error message (`"mhv_id" => "24488346"`) is what MPI returned for your ICN in staging. If this doesn't match your actual staging MHV account, you'll get access denied errors.

**Default MHV IDs** (may not work if they don't match staging):
- User 81 (GREG ANDERSON): `12345748`
- User 228 (JOHN SMITH): `12210827`
- User 36 (WESLEY FORD): `12345749`

## Using Tokens with Upstream Staging Data

You can combine the JWT token approach with the MHV API tunnel to test mobile endpoints against **real staging data** from MHV services (Secure Messaging, Medications, Medical Records, etc.).

### Setup

The JWT token handles **authentication** (proving who you are), while the socat/SOCKS proxy handles **upstream data** (connecting to real MHV services).

**1. Set up the MHV tunnel** (same as vets-website setup):

```bash
# Start SOCKS proxy
vtk socks on

# Start socat tunnel for Secure Messaging
socat TCP-LISTEN:2003,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4428,socksport=2001

# In another terminal, start socat for other MHV services as needed:
# Medications
socat TCP-LISTEN:2004,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4426,socksport=2001

# Medical Records  
socat TCP-LISTEN:2006,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4499,socksport=2001
```

**2. Configure `settings.local.yml`** (same MHV settings from your docs):

```yaml
mhv:
  api_gateway:
    hosts:
      sm_patient: https://localhost:2003
      usermgmt: https://host.docker.internal:2005
  facility_range: [[358, 718], [720, 740], [742, 758], [979, 989]]
  rx:
    host: https://host.docker.internal:2004
    app_token: *ASK A TEAM MEMBER*
    mock: false
    x_api_key: *ASK A TEAM MEMBER*
  sm:
    app_token: *ASK A TEAM MEMBER*
    mock: false
    gw_base_path: v1/sm/patient
    x_api_key: *ASK A TEAM MEMBER*
  medical_records:
    app_id: 103
    app_token: *ASK A TEAM MEMBER*
    x_auth_key: *ASK A TEAM MEMBER*
    host: https://host.docker.internal:2006
  bb:
    mock: false
```

**3. Generate a token with a real MHV correlation ID:**

The mobile endpoints need users with MHV correlation IDs to access MHV services. You have two options:

**Option A: Use a staging MHV user's ICN directly**

```bash
# Look up a staging user's ICN from mvi-staging-users.csv
# Example: vets.gov.user+81@gmail.com has ICN 1008596379V859838
bundle exec rake mobile:generate_token icn=1008596379V859838
```

**Option B: Use your own MHV ID**

If you have a list of staging MHV IDs, specify it when generating the token:

```bash
# Use your actual staging MHV ID
bundle exec rake mobile:generate_mhv_token user_number=81 mhv_id=YOUR_MHV_ID
```

The MHV ID must exist in the staging MHV system and must match what MPI returns for the user's ICN.

**4. Enable dev cache** (required for MHV API calls):

```bash
bin/rails dev:cache
# Should output "Development mode is now being cached"
```

**5. Start vets-api and test:**

```bash
bundle exec rails s

# Test Secure Messaging endpoint
curl -H 'Authorization: Bearer <your-jwt-token>' \
     -H 'Authentication-Method: SIS' \
     -H 'X-Key-Inflection: camel' \
     http://localhost:3000/mobile/v0/messaging/health/folders
```

### How It Works Together

1. **Your JWT token** authenticates you to the mobile API as a valid user
2. **The socat tunnel** routes MHV API calls through the SOCKS proxy to staging
3. **vets-api** makes calls to `localhost:2003` (Secure Messaging), which socat forwards to `fwdproxy-staging.vfs.va.gov:4428`
4. **Staging MHV** returns real data for the user's MHV correlation ID

### Troubleshooting

**"User does not have MHV correlation ID"**

The mobile user needs an MHV correlation ID to access MHV services. Make sure you're using an ICN that corresponds to a real staging MHV user.

**"Connection refused to localhost:2003"**

Make sure socat is running for the service you're trying to access. Check with:
```bash
lsof -i :2003  # Should show socat process
```

**"SSL verification error"**

Make sure `config/initializers/faraday_ssl_noverify.rb` exists in your vets-api repo (it disables SSL verification for local tunneling).

## More Information

- See the rake task implementation: `modules/mobile/lib/tasks/mobile_tasks.rake`
- Mobile authentication controller: `modules/mobile/app/controllers/mobile/application_controller.rb`
- Sign-In Service docs: [SIS Authentication](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/identity)
- Staging MHV users: [mvi-staging-users.csv](https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/Administrative/vagov-users/mvi-staging-users.csv)