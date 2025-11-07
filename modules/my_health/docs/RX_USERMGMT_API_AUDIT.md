# MHV Platform `usermgmt` API Audit

This document identifies which MyHealth API endpoints trigger requests to MHV Platform API paths containing `usermgmt`, including both direct and indirect calls.

**Audit Date:** November 7, 2025

---

## Executive Summary

**Total Endpoints Analyzed:** 12

**Direct `usermgmt` Calls:** 1 endpoint
- `POST /my_health/v1/aal` → `usermgmt/activity`

**Indirect `usermgmt` Calls:** 6 endpoints (all prescription endpoints)
- All prescription endpoints → `usermgmt/auth/session` (via session authentication)

**No `usermgmt` Calls:** 5 endpoints
- 2 medical records (allergies) endpoints
- 3 tooltips endpoints

---

## Direct `usermgmt` API Calls

### POST /my_health/v1/aal
- **Controller:** `MyHealth::V1::AALController`
- **Client:** `AAL::Client` (`lib/mhv/aal/client.rb`)
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - indirect via `authenticate_aal_client!`)
  - `usermgmt/activity` (direct - primary purpose)
- **Purpose:** Creates account activity log entries in MHV
- **Call Chain:** Controller → `AAL::Client#create_aal` → `POST usermgmt/activity`

---

## Indirect `usermgmt` API Calls

All prescription endpoints make **indirect** calls to `usermgmt/auth/session` for authentication.

### Authentication Call Chain

1. All prescription controllers inherit from `RxController`
2. `RxController` includes `MyHealth::MHVControllerConcerns`
3. The concern defines `before_action :authenticate_client`
4. This calls `client.authenticate` on the `Rx::Client`
5. `Rx::Client` includes `MHVSessionBasedClient` which calls `get_session` during authentication
6. `get_session` calls `get_session_tagged`
7. `Rx::Client` overrides `get_session_tagged` to call `GET usermgmt/auth/session`

### Prescription Endpoints (All Call `usermgmt/auth/session`)

#### GET /my_health/v1/prescriptions
- **Controller:** `MyHealth::V1::PrescriptionsController`
- **Client:** `Rx::Client`
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - **indirect**)
  - `pharmacy/ess/getactiverx` OR `pharmacy/ess/gethistoryrx` (primary data)
- **Call Chain:** `before_action :authenticate_client` → `Rx::Client#get_session_tagged` → `GET usermgmt/auth/session`

#### GET /my_health/v1/prescriptions/{id}
- **Controller:** `MyHealth::V1::PrescriptionsController`
- **Client:** `Rx::Client`
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - **indirect**)
  - `pharmacy/ess/gethistoryrx` OR `pharmacy/ess/medications` (primary data)

#### GET /my_health/v1/prescriptions/list_refillable_prescriptions
- **Controller:** `MyHealth::V1::PrescriptionsController`
- **Client:** `Rx::Client`
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - **indirect**)
  - `pharmacy/ess/getactiverx` OR `pharmacy/ess/gethistoryrx` (primary data)

#### GET /my_health/v1/prescriptions/{id}/documentation
- **Controller:** `MyHealth::V1::PrescriptionDocumentationController`
- **Client:** `Rx::Client`
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - **indirect**)
  - `pharmacy/ess/medications` (get prescription details)
  - `pharmacy/ess/getrxdoc/{ndc}` (primary data)

#### PATCH /my_health/v1/prescriptions/{id}/refill
- **Controller:** `MyHealth::V1::PrescriptionsController`
- **Client:** `Rx::Client`
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - **indirect**)
  - `pharmacy/ess/rxrefill/{id}` (primary action)

#### PATCH /my_health/v1/prescriptions/refill_prescriptions
- **Controller:** `MyHealth::V1::PrescriptionsController`
- **Client:** `Rx::Client`
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - **indirect**)
  - `pharmacy/ess/rxrefill/{id}` (primary action - called per prescription ID)

---

## Endpoints That Do NOT Call `usermgmt` Paths

### Medical Records (Allergies) Endpoints

#### GET /my_health/v1/medical_records/allergies
- **Controller:** `MyHealth::V1::AllergiesController`
- **Client:** `MedicalRecords::Client`
- **API Paths Called:** FHIR API (`AllergyIntolerance` search)
- **Note:** Uses different authentication mechanism (MHV FHIR session)

#### GET /my_health/v1/medical_records/allergies/{id}
- **Controller:** `MyHealth::V1::AllergiesController`
- **Client:** `MedicalRecords::Client`
- **API Paths Called:** FHIR API (`AllergyIntolerance` read)
- **Note:** Uses different authentication mechanism (MHV FHIR session)

### Tooltips Endpoints (Database Only)

#### GET /my_health/v1/tooltips
- **Controller:** `MyHealth::V1::TooltipsController`
- **Operations:** Database query only
- **API Paths Called:** None (no external API calls)

#### POST /my_health/v1/tooltips
- **Controller:** `MyHealth::V1::TooltipsController`
- **Operations:** Database insert only
- **API Paths Called:** None (no external API calls)

#### PATCH /my_health/v1/tooltips/{tooltipId}
- **Controller:** `MyHealth::V1::TooltipsController`
- **Operations:** Database update only
- **API Paths Called:** None (no external API calls)---

## Summary Table

| Endpoint | Direct `usermgmt` Call | Indirect `usermgmt/auth/session` | Indirect `usermgmt/notification/*` | Primary API Path |
|----------|----------------------|--------------------------------|----------------------------------|------------------|
| GET /my_health/v1/prescriptions | ❌ | ✅ Yes (auth) | ❌ | `pharmacy/ess/*` |
| GET /my_health/v1/prescriptions/{id} | ❌ | ✅ Yes (auth) | ❌ | `pharmacy/ess/*` |
| GET /my_health/v1/prescriptions/list_refillable_prescriptions | ❌ | ✅ Yes (auth) | ❌ | `pharmacy/ess/*` |
| GET /my_health/v1/prescriptions/{id}/documentation | ❌ | ✅ Yes (auth) | ❌ | `pharmacy/ess/getrxdoc/{ndc}` |
| PATCH /my_health/v1/prescriptions/{id}/refill | ❌ | ✅ Yes (auth) | ❌ | `pharmacy/ess/rxrefill/{id}` |
| PATCH /my_health/v1/prescriptions/refill_prescriptions | ❌ | ✅ Yes (auth) | ❌ | `pharmacy/ess/rxrefill/{id}` |
| GET /my_health/v1/medical_records/allergies | ❌ | ❌ | ❌ | FHIR API |
| GET /my_health/v1/medical_records/allergies/{id} | ❌ | ❌ | ❌ | FHIR API |
| GET /my_health/v1/tooltips | ❌ | ❌ | ❌ | Database only |
| POST /my_health/v1/tooltips | ❌ | ❌ | ❌ | Database only |
| PATCH /my_health/v1/tooltips/{tooltipId} | ❌ | ❌ | ❌ | Database only |
| POST /my_health/v1/aal | ✅ `usermgmt/activity` | ✅ Yes (auth) | ❌ | `usermgmt/activity` |

---

## Additional Prescription Preference Endpoints

These endpoints were not in the original analysis but also interact with `usermgmt` paths:

### GET /my_health/v1/prescriptions/preferences
- **Controller:** `MyHealth::V1::PrescriptionPreferencesController`
- **Client:** `Rx::Client`
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - **indirect**)
  - `usermgmt/notification/email` (preference retrieval - **indirect**)
  - `usermgmt/notification/rx` (preference retrieval - **indirect**)
- **Call Chain:** Controller → `Rx::Client#get_preferences` → parallel calls to `get_notification_email_address` and `get_rx_preference_flag`

### PATCH /my_health/v1/prescriptions/preferences
- **Controller:** `MyHealth::V1::PrescriptionPreferencesController`
- **Client:** `Rx::Client`
- **API Paths Called:**
  - `usermgmt/auth/session` (authentication - **indirect**)
  - `usermgmt/notification/email` (preference update - **indirect**)
  - `usermgmt/notification/rx` (preference update - **indirect**)
- **Call Chain:** Controller → `Rx::Client#post_preferences` → calls to `post_notification_email_address` and `post_rx_preference_flag`

---

## Additional Context

### Other Clients Using `usermgmt` Paths

While not directly exposed through the endpoints analyzed above, the following clients also interact with `usermgmt` paths:

#### 1. BBInternal::Client (`lib/medical_records/bb_internal/client.rb`)
Used by Medical Records controllers for various operations:
- `usermgmt/patient/uid/{user_id}` - Patient information retrieval
- `usermgmt/notification/bbmi` - BBMI notification settings
- `usermgmt/emergencycontacts/{user_id}` - Emergency contacts
- `usermgmt/auth/session` - Authentication

#### 2. Rx::Client (`lib/rx/client.rb`)
Session and preference management:
- `usermgmt/auth/session` - Session authentication
- `usermgmt/notification/email` - Email notification preferences
- `usermgmt/notification/rx` - Prescription notification preferences

#### 3. AAL Clients (`lib/mhv/aal/client.rb`)
Account Activity Logging for different products:
- `AAL::MRClient` - Medical Records activity logging
- `AAL::RXClient` - Prescriptions activity logging
- `AAL::SMClient` - Secure Messaging activity logging
- All use:
  - `usermgmt/activity` - Activity log creation
  - `usermgmt/auth/session` - Authentication

#### 4. MHV Account Creation (`lib/mhv/account_creation/`)
- `v1/usermgmt/account-service/account` - MHV account creation

#### 5. User Eligibility (`lib/medical_records/user_eligibility/`)
- `v1/usermgmt/usereligibility/*` - User eligibility checks

### Authentication Pattern

The `MHVSessionBasedClient` concern (in `lib/common/client/concerns/mhv_session_based_client.rb`) provides the standard authentication pattern used by most MHV clients:

```ruby
# Default implementation (can be overridden)
def get_session_tagged
  perform(:get, 'session', nil, auth_headers)
end
```

The `Rx::Client` overrides this to explicitly call the `usermgmt` endpoint:

```ruby
# Rx::Client override
def get_session_tagged
  Sentry.set_tags(error: 'mhv_session')
  env = perform(:get, 'usermgmt/auth/session', nil, auth_headers)
  Sentry.get_current_scope.tags.delete(:error)
  env
end
```

### Session Caching

**Important:** Calls to `usermgmt/auth/session` ARE cached using Redis.

#### Caching Mechanism

Sessions obtained from `usermgmt/auth/session` are stored in Redis to avoid repeated authentication calls:

- **Storage:** `Rx::ClientSession` class (`lib/rx/client_session.rb`)
- **Redis Namespace:** `rx-service`
- **TTL (Time To Live):** **1200 seconds (20 minutes)**
- **Cache Key:** Based on `user_id` (MHV correlation ID)
- **Configuration:** `config/redis.yml` → `rx_store`

#### How Session Caching Works

When `client.authenticate` is called:

1. **Check Redis:** `Rx::ClientSession.find_or_build(session)` looks for an existing session in Redis
2. **Validate Session:** Checks if the session is expired (uses 20-second threshold before actual expiration)
3. **Cache Hit or Miss:**
   - ✅ **Valid session exists** → Reuses cached session (**NO API call to `usermgmt/auth/session`**)
   - ❌ **Session expired or missing** → Calls `usermgmt/auth/session` and caches the new session

#### Concurrent Request Handling

To prevent multiple simultaneous authentication calls from the same user:

- **Redis Lock:** `mhv_session_lock:{user_key}`
- **Lock TTL:** 10 seconds
- **Retry Logic:** Up to 40 attempts with 0.3-second delays between attempts
- **Behavior:** Only the first concurrent request calls `usermgmt/auth/session`; others wait and reuse the newly created session

#### Session Expiration

From `Common::Client::Session`:
```ruby
EXPIRATION_THRESHOLD_SECONDS = 20

def expired?
  return true if expires_at.nil?
  expires_at.to_i <= Time.now.utc.to_i + EXPIRATION_THRESHOLD_SECONDS
end
```

Sessions are considered expired **20 seconds before** their actual expiration time to provide a safety buffer for request processing.

#### Practical Impact

- **First request** from a user → Calls `usermgmt/auth/session`
- **Subsequent requests within 20 minutes** → Use cached session (**no `usermgmt/auth/session` call**)
- **After 20 minutes** → Session expires, next request calls `usermgmt/auth/session` again
- **Different users** → Each has their own cached session (cache key includes user ID)

---

## Methodology

This audit was conducted by:

1. **Controller Analysis:** Traced each endpoint to its controller and identified the client used
2. **Client Method Tracing:** Examined which client methods are called for each endpoint action
3. **API Path Construction:** Analyzed how API paths are constructed in client HTTP request methods
4. **Authentication Flow:** Traced the `before_action` callbacks and authentication mechanisms
5. **Code Search:** Searched for `usermgmt` string patterns across the codebase
6. **Inheritance Chain:** Analyzed controller inheritance and module inclusions (concerns)

### Key Findings

1. **Authentication is Implicit:** All `Rx::Client` operations trigger `usermgmt/auth/session` via the `before_action :authenticate_client` callback, even though the primary operations use `pharmacy/ess` endpoints.

2. **Session Caching Reduces Load:** Authentication sessions are cached in Redis for 20 minutes. This means `usermgmt/auth/session` is only called once per user every 20 minutes, not on every request. Subsequent requests within the 20-minute window reuse the cached session token.

3. **Concurrent Request Protection:** Redis locks prevent multiple simultaneous authentication calls from the same user, avoiding the "thundering herd" problem.

4. **Preference Operations:** Prescription preference endpoints make multiple parallel calls to `usermgmt/notification/*` endpoints.

5. **Database-Only Operations:** Tooltips endpoints have no external API dependencies.

6. **FHIR vs UserMgmt:** Medical Records (allergies) use the FHIR API infrastructure which has a different authentication mechanism and does not call `usermgmt` paths.

7. **AAL Dual Purpose:** The AAL endpoint both authenticates (indirect call to `usermgmt/auth/session`) and logs activity (direct call to `usermgmt/activity`).

---

## Impact Assessment

### Endpoints with `usermgmt` Dependencies

**7 of 12 endpoints** (58%) have dependencies on `usermgmt` API paths:
- 6 prescription endpoints (indirect via authentication)
- 1 AAL endpoint (both direct and indirect)

### Critical Dependencies

If the `usermgmt` API experiences issues:
- **All prescription operations** will fail to authenticate (unless cached session is still valid)
- **Prescription preferences** will be unavailable
- **AAL logging** will fail

**Note:** The 20-minute session cache provides some resilience. If `usermgmt` goes down temporarily, users with valid cached sessions can continue using prescription endpoints until their sessions expire.

### Session Cache Resilience

The Redis-based session caching provides a buffer against `usermgmt` API issues:
- **Best case:** If `usermgmt` recovers within 20 minutes, impact is minimal (only users without cached sessions affected)
- **Worst case:** After 20 minutes, all sessions expire and all users will be unable to authenticate

### Non-Affected Services

The following will continue to function:
- Tooltips (database-only)
- Medical Records allergies (uses FHIR API with different auth)

