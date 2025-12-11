# Rx::Client `get_session_tagged` Usage

## Overview

The `get_session_tagged` method in `Rx::Client` is called to establish and maintain MHV (My HealtheVet) session authentication for prescription-related API operations.

## Call Location

`get_session_tagged` is called **indirectly** through inheritance from the `MHVSessionBasedClient` concern.

### Call Chain

1. **`Rx::Client`** (line 15 in `lib/rx/client.rb`)
   - Includes `Common::Client::Concerns::MHVSessionBasedClient`

2. **`MHVSessionBasedClient#get_session`** (line 50 in `lib/common/client/concerns/mhv_session_based_client.rb`)
   - The inherited `get_session` method calls `get_session_tagged`
   - This method is responsible for creating/refreshing the session from request/response headers

3. **`Rx::Client#get_session_tagged`** (lines 193-198 in `lib/rx/client.rb`)
   - Override implementation specific to Rx operations
   - Adds Sentry error tagging for MHV session operations
   - Makes API call to `usermgmt/auth/session` endpoint

## Implementation Details

### `Rx::Client#get_session_tagged`

```ruby
def get_session_tagged
  Sentry.set_tags(error: 'mhv_session')
  env = perform(:get, 'usermgmt/auth/session', nil, auth_headers)
  Sentry.get_current_scope.tags.delete(:error)
  env
end
```

**Purpose:**
- Authenticates with MHV's user management API
- Establishes a session for prescription-related operations
- Tags errors in Sentry for tracking MHV session issues

**API Endpoint:** `usermgmt/auth/session`

**Returns:** Faraday environment object containing:
- Request headers (including `mhvCorrelationId`)
- Response headers (including `expires` and `token`)

### When It's Called

The `get_session_tagged` method is invoked whenever:
- A new `Rx::Client` instance needs to establish a session
- An existing session needs to be refreshed/validated
- Any MHV-locked operation requires session authentication

This happens automatically through the `MHVSessionBasedClient` concern's session management logic, which:
1. Checks if a session exists and is valid
2. Calls `get_session_tagged` to authenticate
3. Extracts session tokens and metadata from headers
4. Stores the session for subsequent API calls

## Related Files

- `lib/rx/client.rb` - Rx::Client implementation
- `lib/common/client/concerns/mhv_session_based_client.rb` - Session management concern
- `lib/rx/client_session.rb` - Session model for Rx operations
- `lib/rx/configuration.rb` - Configuration including app_token and endpoints
