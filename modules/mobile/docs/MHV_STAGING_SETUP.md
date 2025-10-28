# Testing Mobile Endpoints with MHV Staging Data

This guide explains how to test mobile API endpoints locally while connecting to **real MHV staging services** (Secure Messaging, Medications, Medical Records, etc.).

## Overview

This setup combines:
- **JWT token authentication** (authenticates you to the mobile API locally)
- **SOCKS proxy + socat tunnels** (routes MHV API calls to staging services)
- **Staging MHV user data** (real messages, medications, etc. from staging)

## Prerequisites

- SOCKS proxy access (`vtk` command available)
- `socat` installed (`brew install socat`)
- Redis running locally
- MHV API credentials (ask a team member for app_token and x_api_key values)

## Complete Setup Workflow

### Step 1: Configure settings.local.yml

Create or update `config/settings.local.yml` with MHV configuration:

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

### Step 2: Ensure SSL Verification is Disabled

Make sure `config/initializers/faraday_ssl_noverify.rb` exists. This file disables SSL verification for local tunneling.

### Step 3: Start SOCKS Proxy

```bash
vtk socks on
```

Verify it's running:
```bash
# Should show listening on port 2001
lsof -i :2001
```

### Step 4: Start socat Tunnels

**Option A: Use the helper script (recommended)**

```bash
./modules/mobile/bin/start_mhv_tunnels.sh
```

This will:
- Check if SOCKS proxy is running (and start it if needed)
- Start all three tunnels (Secure Messaging, Medications, Medical Records)
- Keep running until you press Ctrl+C
- Provide clear status messages

To stop the tunnels:
```bash
./modules/mobile/bin/stop_mhv_tunnels.sh
```

**Option B: Start tunnels manually**

Open separate terminal windows/tabs for each service:

**Terminal 1 - Secure Messaging:**
```bash
socat TCP-LISTEN:2003,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4428,socksport=2001
```

**Terminal 2 - Medications (Rx):**
```bash
socat TCP-LISTEN:2004,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4426,socksport=2001
```

**Terminal 3 - Medical Records:**
```bash
socat TCP-LISTEN:2006,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4499,socksport=2001
```

**Verify tunnels are running:**
```bash
lsof -i :2003
lsof -i :2004
lsof -i :2006
```

### Step 5: Enable Development Cache

```bash
cd vets-api
bin/rails dev:cache
```

Should output: `Development mode is now being cached.`

(Run the command again to toggle it off)

### Step 6: Generate JWT Token for Staging User

```bash
bundle exec rake mobile:generate_mhv_token user_number=81
```

This generates a token for a real staging MHV user. Available users:
- `81` - GREG ANDERSON (vets.gov.user+81@gmail.com) - Default MHV ID: 12345748
- `228` - JOHN SMITH (vets.gov.user+228@gmail.com) - Default MHV ID: 12210827
- `36` - WESLEY FORD (vets.gov.user+36@gmail.com) - Default MHV ID: 12345749

**IMPORTANT**: The MHV ID must match what MPI returns for the user's ICN in staging. If you have a list of actual MHV IDs from staging, you can override the default:

```bash
bundle exec rake mobile:generate_mhv_token user_number=81 mhv_id=YOUR_ACTUAL_MHV_ID
```

This ensures the token is created with the correct MHV correlation ID that exists in the staging MHV system.

Copy the JWT token from the output.

### Step 7: Start vets-api

```bash
bundle exec rails s
```

### Step 8: Test Mobile Endpoints

**Test Secure Messaging (list folders):**
```bash
curl -H 'Authorization: Bearer <your-jwt-token>' \
     -H 'Authentication-Method: SIS' \
     -H 'X-Key-Inflection: camel' \
     http://localhost:3000/mobile/v0/messaging/health/folders
```

**Test Medications (list prescriptions):**
```bash
curl -H 'Authorization: Bearer <your-jwt-token>' \
     -H 'Authentication-Method: SIS' \
     -H 'X-Key-Inflection: camel' \
     http://localhost:3000/mobile/v0/health/rx/prescriptions
```

**Test Medical Records:**
```bash
curl -H 'Authorization: Bearer <your-jwt-token>' \
     -H 'Authentication-Method: SIS' \
     -H 'X-Key-Inflection: camel' \
     http://localhost:3000/mobile/v0/health/medical_records
```

### In Postman

1. Create a new request to any mobile MHV endpoint
2. Set headers:
   - **Authorization**: `Bearer <your-jwt-token>`
   - **Authentication-Method**: `SIS`
   - **X-Key-Inflection**: `camel`
3. Send the request

## How It Works

```
[Postman/curl]
     |
     | JWT token in Authorization header
     v
[Mobile API (localhost:3000)]
     |
     | Authenticated request
     v
[MHV Service Client]
     |
     | HTTP call to localhost:2003 (or 2004, 2006)
     v
[socat tunnel]
     |
     | Forwards through SOCKS proxy (port 2001)
     v
[SOCKS Proxy]
     |
     | Connects to staging forward proxy
     v
[fwdproxy-staging.vfs.va.gov:4428]
     |
     | Real MHV staging service
     v
[MHV Staging API]
     |
     | Returns real data for user's MHV ID
     v
[Response flows back through the chain]
```

## Troubleshooting

### "SM ACCESS DENIED IN MOBILE POLICY"

This error means the MHV correlation ID doesn't match what's in staging MPI/MHV. Common causes:

1. **MHV ID mismatch**: The MHV ID in your token doesn't match what MPI returns for that ICN in staging
2. **Wrong user**: You're using a locally-generated user instead of a staging user

**Solution**: Use a real staging user with the correct MHV ID:

```bash
# Get the actual MHV ID for your staging user from your list
bundle exec rake mobile:generate_mhv_token user_number=81 mhv_id=YOUR_ACTUAL_STAGING_MHV_ID
```

If you don't have the MHV IDs, you can:
1. Check the staging MVI user CSV file
2. Use the default MHV IDs (may not work)
3. Contact a team member for the MHV ID list

### "User does not have MHV correlation ID"

The user doesn't have an MHV correlation ID at all. Make sure you're using `generate_mhv_token` (not `generate_token`):

```bash
bundle exec rake mobile:generate_mhv_token user_number=81 mhv_id=YOUR_MHV_ID
```

### "Connection refused to localhost:2003"

Socat tunnel is not running. Start it:
```bash
socat TCP-LISTEN:2003,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4428,socksport=2001
```

### "SOCKS5 request failed"

SOCKS proxy is not running:
```bash
vtk socks on
```

### "Access token JWT is malformed"

Missing the `Authentication-Method: SIS` header. Make sure all three headers are present:
- `Authorization: Bearer <token>`
- `Authentication-Method: SIS`
- `X-Key-Inflection: camel`

### "SSL verification error" or "certificate verify failed"

Make sure `config/initializers/faraday_ssl_noverify.rb` exists.

### Cache errors

Enable development cache:
```bash
bin/rails dev:cache
```

### Token expired

Tokens expire after 30 minutes. Generate a new one:
```bash
bundle exec rake mobile:generate_mhv_token user_number=81
```

Or create a longer-lived token:
```bash
bundle exec rake mobile:generate_mhv_token user_number=81 duration=120
```

## Testing Different Users

Each staging user may have different data in MHV staging. If you have a list of actual MHV IDs from staging, use them:

```bash
# User 81 - GREG ANDERSON (with custom MHV ID)
bundle exec rake mobile:generate_mhv_token user_number=81 mhv_id=YOUR_MHV_ID

# User 228 - JOHN SMITH (with custom MHV ID)
bundle exec rake mobile:generate_mhv_token user_number=228 mhv_id=YOUR_MHV_ID

# User 36 - WESLEY FORD (with custom MHV ID)
bundle exec rake mobile:generate_mhv_token user_number=36 mhv_id=YOUR_MHV_ID

# Or use defaults (may not work if MHV IDs don't match staging)
bundle exec rake mobile:generate_mhv_token user_number=81
```

**Why the MHV ID matters**: When you access MHV services (Secure Messaging, Medications, etc.), the mobile API:
1. Looks up your user profile in MPI using the ICN
2. Gets the MHV correlation ID from MPI
3. Uses that MHV ID to authenticate with MHV staging services

If the MHV ID in the token doesn't match what MPI returns for that ICN in staging, you'll get "SM ACCESS DENIED IN MOBILE POLICY" errors.

## Cleanup

When done testing:

```bash
# Stop all tunnels (if using helper script)
./modules/mobile/bin/stop_mhv_tunnels.sh

# Or manually stop socat tunnels (Ctrl+C in each terminal)

# Stop SOCKS proxy (if not already stopped)
vtk socks off

# Clean up test database records
bundle exec rake mobile:cleanup_test_data

# Disable dev cache (optional)
bin/rails dev:cache
```

## Port Reference

| Port | Service | Forward Proxy Endpoint |
|------|---------|------------------------|
| 2001 | SOCKS Proxy | (local) |
| 2003 | Secure Messaging | fwdproxy-staging.vfs.va.gov:4428 |
| 2004 | Medications (Rx) | fwdproxy-staging.vfs.va.gov:4426 |
| 2006 | Medical Records | fwdproxy-staging.vfs.va.gov:4499 |

## Related Documentation

- [Local Testing Guide](LOCAL_TESTING.md) - Basic JWT token generation
- [Forward Proxy Config](https://github.com/department-of-veterans-affairs/vsp-platform-fwdproxy/blob/master/fwdproxy-config/fwdproxy-vagov-staging-vars.yml) - Port mappings
- [MVI Staging Users](https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/Administrative/vagov-users/mvi-staging-users.csv) - Staging user data

## Quick Reference

**Full setup using helper scripts:**

```bash
# Terminal 1 - Start tunnels
./modules/mobile/bin/start_mhv_tunnels.sh
# Keep this running

# Terminal 2 - Setup and API
bin/rails dev:cache
bundle exec rake mobile:generate_mhv_token user_number=81
# Copy the JWT token
bundle exec rails s

# Terminal 3 - Test
curl -H 'Authorization: Bearer <token>' \
     -H 'Authentication-Method: SIS' \
     -H 'X-Key-Inflection: camel' \
     http://localhost:3000/mobile/v0/messaging/health/folders
```

**Full setup manually (without helper scripts):**

```bash
# Terminal 1 - Setup and API
vtk socks on
bin/rails dev:cache
bundle exec rake mobile:generate_mhv_token user_number=81
# Copy the JWT token
bundle exec rails s

# Terminal 2 - Secure Messaging tunnel
socat TCP-LISTEN:2003,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4428,socksport=2001

# Terminal 3 - Medications tunnel
socat TCP-LISTEN:2004,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4426,socksport=2001

# Terminal 4 - Medical Records tunnel
socat TCP-LISTEN:2006,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4499,socksport=2001

# Terminal 5 - Test
curl -H 'Authorization: Bearer <token>' \
     -H 'Authentication-Method: SIS' \
     -H 'X-Key-Inflection: camel' \
     http://localhost:3000/mobile/v0/messaging/health/folders
```
