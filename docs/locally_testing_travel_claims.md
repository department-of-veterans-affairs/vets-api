# Testing Travel Claims Endpoints

> **Important Note About Local Setup**:
> While this guide attempts to be comprehensive, setting up the full travel claims process locally is a nuanced and complex task that may require debugging and experimentation. You will likely need to:
> - Read and understand the betamocks documentation in detail (`modules/check_in/README.md` and related docs)
> - Experiment with different configuration settings
> - Debug various parts of the process as you set them up
> - Iterate on the setup as you encounter specific issues
>
> The configurations and steps provided here are a starting point, but due to the interconnected nature of the services and the complexity of the mocking system, you may need to adjust them based on your specific situation and any recent changes to the codebase.

> **Important Note About Configurations**:
> The configuration settings outlined in this guide may or may not be merged into the master branch at the time you're reading this. These settings affect multiple teams and services, so their integration into the main codebase is subject to review and approval processes. You may need to:
> - Check if these settings exist in your current branch
> - Add missing configurations locally if needed
> - Consult with your team lead about the status of these configurations
> - Be prepared to maintain these settings locally until they are merged

## Testing Prerequisites

### Important Note
Testing the travel claim async flow locally requires setting up multiple external service mocks and ensuring proper configuration across several systems. **Expect some trial and error** with configuration settings as the system has many interdependent components.

### Required Local Services

Before beginning the testing process, you'll need to have several services running locally. Open separate terminal windows for each of the following:

1. **Rails Server**
   ```bash
   bundle exec rails server
   ```
   This will start your local vets-api server on port 3000.

2. **Redis Server**
   ```bash
   redis-server
   ```
   Redis is required for session management and caching user data between LoROTA calls and job execution.

3. **Sidekiq Worker**
   ```bash
   bundle exec sidekiq
   ```
   Sidekiq processes the asynchronous jobs that handle travel claim submissions.

Keep all these terminal windows open and visible to monitor the request processing and async job execution.

### Configuration Setup

1. **Betamocks Configuration**
In `config/settings/development.yml`, ensure these settings:
```yaml
betamocks:
  enabled: true
  recording: false  # Set to true only if you need to record new responses
  cache_dir: "../vets-api-mockdata"
  services_config: config/betamocks/services_config.yml
```

2. **Service Configurations**
Update the following in `config/betamocks/services_config.yml`:
```yaml
# VA Notify Configuration
- :name: "VA Notify"
  :endpoints:
    - :method: :post
      :path: "/v2/notifications/sms"
      :file_path: "va_notify/sms"
      :cache_multiple_responses:
        :uid_location: body
        :uid_locator: '"phone_number":"([^"]+)"'

# Travel Claims Configuration
- :name: "Travel Claims"
  :endpoints:
    - :method: :post
      :path: <%= "/#{Settings.check_in.travel_reimbursement_api_v2.claims_base_path}/api/ClaimIngest/submitclaim" %>
      :file_path: "/travel_claim/submitclaim/default"
      :response_delay: 1
```

3. **Feature Flags**
Enable these flags in development:
```yaml
check_in_experience_mock_enabled: true
check_in_experience_travel_reimbursement: true
check_in_experience_cerner_travel_claims_enabled: true
check_in_experience_check_claim_status_on_timeout: true
```

### Required Mock Data

Ensure these mock response files exist in your `vets-api-mockdata` directory:
```
/lorota/token/        # LoROTA authentication responses
/lorota/data/         # LoROTA session data responses
/travel_claim/token/  # BTSSS authentication responses
/travel_claim/submitclaim/  # BTSSS claim submission responses
/travel_claim/claimstatus/  # BTSSS status check responses
```

### Required SSL Key File

The LoROTA service configuration references a key file at `tmp/fake_api_path`. You need to create this file with a valid SSL private key:

1. Create the directory if it doesn't exist:
   ```bash
   mkdir -p tmp
   ```

2. Generate a fake SSL key:
   ```bash
   openssl genrsa -out tmp/fake_api_path 2048
   ```

3. Verify the key was created:
   ```bash
   ls -la tmp/fake_api_path
   ```

This file is required even when using mock services, as the code path still attempts to load the key file.

## Terminal Window Output Guide

As you progress through the testing steps, you should see specific activity in each terminal window:

### Rails Server Window
- During authentication:
  ```
  Started GET "/v0/sign_in/authorize"
  Processing by V0::SignIn::AuthorizationController#authorize
  ```

- When creating check-in session:
  ```
  Started POST "/check_in/v2/sessions"
  Processing by CheckIn::V2::SessionsController#create
  ```

- When getting patient status:
  ```
  Started GET "/check_in/v2/patient_check_ins/[uuid]"
  Processing by CheckIn::V2::PatientCheckInsController#show
  [LoROTA] Fetching patient data...
  ```

- When submitting travel claim:
  ```
  Started POST "/check_in/v0/travel_claims"
  Processing by CheckIn::V0::TravelClaimsController#create
  Enqueuing TravelClaimSubmissionJob
  ```

### Redis Server Window
You'll see cache operations happening:
```
[timestamp] "set" "[check_in:session:uuid]"  # When session is created
[timestamp] "get" "[check_in:session:uuid]"  # When retrieving patient data
[timestamp] "set" "[check_in:travel_claim:uuid]"  # When caching claim data
```

### Sidekiq Window
After submitting the travel claim, you'll see this sequence of jobs:

1. Initial claim submission:
```
TravelClaimSubmissionJob JID-[some-id] INFO: start
Processing travel claim for patient [uuid]
Calling BTSSS API...
```

2. SMS notification job:
```
VANotify::AsyncJob JID-[some-id] INFO: start
Sending SMS notification to [masked-phone-number]
```

3. Status update job:
```
TravelClaimStatusUpdateJob JID-[some-id] INFO: start
Updating status for claim [uuid]
```

Each job will show either:
```
INFO: done: [time]s  # For successful completion
ERROR: fail: [time]s # If there's an error
```

### Rails Logger Output

During the travel claim process, you should see detailed logging in your Rails server window. Here's what to expect at each step:

#### 1. Session Creation
```
[CheckIn::V2::SessionsController] Creating new check-in session
[CheckIn::V2::SessionsController] Session params: {"uuid"=>"5bcd636c-d4d3-4349-9058-03b2f6b38ced", "facility_type"=>"cie"}
[CheckIn::V2::LoROTA::Service] Fetching LoROTA token
[CheckIn::V2::LoROTA::Service] Successfully retrieved LoROTA token
[CheckIn::V2::SessionsController] Successfully created check-in session
```

#### 2. Patient Check-In Status
```
[CheckIn::V2::PatientCheckInsController] Fetching patient check-in status
[CheckIn::V2::LoROTA::Service] Fetching patient data for uuid: 5bcd636c-d4d3-4349-9058-03b2f6b38ced
[CheckIn::V2::LoROTA::Service] Successfully retrieved patient data
[CheckIn::V2::PatientCheckInsController] Caching patient data for travel claim
```

#### 3. Travel Claim Submission
```
[CheckIn::V0::TravelClaimsController] Initiating travel claim submission
[CheckIn::TravelClaim::Service] Building travel claim for patient
[CheckIn::TravelClaim::Service] Retrieved cached patient data
[CheckIn::TravelClaim::Service] Enqueuing TravelClaimSubmissionJob with uuid: 5bcd636c-d4d3-4349-9058-03b2f6b38ced
```

#### 4. Background Job Processing
```
[TravelClaimSubmissionJob] Starting job for claim uuid: 5bcd636c-d4d3-4349-9058-03b2f6b38ced
[CheckIn::TravelClaim::Client] Requesting BTSSS authentication token
[CheckIn::TravelClaim::Client] Successfully obtained BTSSS token
[CheckIn::TravelClaim::Client] Submitting claim to BTSSS
[CheckIn::TravelClaim::Client] Claim submitted successfully
[VANotify::Service] Sending SMS notification for successful claim submission
[TravelClaimStatusUpdateJob] Scheduling status check for claim
```

#### 5. Status Updates
```
[TravelClaimStatusUpdateJob] Checking status for claim uuid: 5bcd636c-d4d3-4349-9058-03b2f6b38ced
[CheckIn::TravelClaim::Client] Fetching claim status from BTSSS
[CheckIn::TravelClaim::Client] Status received: PROCESSED
[VANotify::Service] Sending final status notification
```

#### Common Error Logs to Watch For

1. Authentication Issues:
```
[CheckIn::V2::LoROTA::Service] Failed to obtain LoROTA token: Unauthorized
[CheckIn::TravelClaim::Client] BTSSS authentication failed: Invalid credentials
```

2. Data Validation Issues:
```
[CheckIn::V0::TravelClaimsController] Invalid claim parameters: Missing required fields
[CheckIn::TravelClaim::Service] Failed to build claim: Invalid appointment date
```

3. Service Integration Issues:
```
[CheckIn::TravelClaim::Client] BTSSS API connection timeout
[VANotify::Service] Failed to send SMS notification: Service unavailable
```

4. Cache Issues:
```
[CheckIn::TravelClaim::Service] Failed to retrieve cached patient data
[CheckIn::V2::PatientCheckInsController] Session data not found in cache
```

These logs provide insight into:
- The flow of data through the system
- Success/failure of external service calls
- Background job processing status
- Error conditions and their causes

When troubleshooting, search for these log patterns to identify where in the process an issue might be occurring.

## Testing Steps

### 1. Authentication Setup
Before testing the endpoints, authenticate using the low-auth flow with two sequential requests:

#### a. Initialize Authorization
```http
GET http://localhost:3000/v0/sign_in/authorize
```
Required query parameters:
```
acr=ial2
client_id=vamock
response_type=code
type=logingov
code_challenge=JNkFflCkxk1K6gQUf23P_5Ctl_T65_xkkOU_y-Cc2XI=
code_challenge_method=S256
```

#### b. Complete Authentication
```http
GET http://localhost:3000/mocked_authentication/authorize
```
Required query parameters:
```
credential_info=[encoded credential info]
state=[encoded state]
```

Note: The second request will return a bearer token needed for subsequent requests.

### 2. Test Check-In Flow

#### Step 1: Create Check-In Session
```http
POST http://localhost:3000/check_in/v2/sessions
Content-Type: application/json
Authorization: Bearer [your-token]

{
    "session": {
        "uuid": "5bcd636c-d4d3-4349-9058-03b2f6b38ced",
        "dob": "1945-02-13",
        "last_name": "Smith",
        "facility_type": "cie"
    }
}
```

#### Step 2: Get Patient Check-In Status
This caches the user data needed for claim submission:
```http
GET http://localhost:3000/check_in/v2/patient_check_ins/5bcd636c-d4d3-4349-9058-03b2f6b38ced
Content-Type: application/json

{
    "facilityType": "cie",
    "handoff": "true"
}
```

#### Step 3: Submit Travel Claim
This initiates the async claim submission process:
```http
POST http://localhost:3000/check_in/v0/travel_claims
Content-Type: application/json
Accept: application/json

{
    "travel_claims": {
        "uuid": "5bcd636c-d4d3-4349-9058-03b2f6b38ced",
        "appointment_date": "2023-05-01",
        "facility_type": "vamc",
        "time_to_complete": 5
    }
}
```

## Troubleshooting Common Issues

Watch for these common issues in the terminal output:

### Rails Server Issues
- 401 Unauthorized errors during authentication
- 404 Not Found if UUIDs don't match between requests
- 422 Unprocessable Entity if request data is invalid

### Redis Server Issues
- Connection refused errors (indicates Redis isn't running)
- Key not found errors (indicates session data expired)

### Sidekiq Issues
- Job retry messages (indicates temporary failures)
- Stack traces (indicates code errors)
- Connection timeout errors (indicates API connectivity issues)

### General Checklist
If you encounter issues, verify:
- All services are running
- You're using matching UUIDs across requests
- Your mock data files are properly configured
- Your authentication token hasn't expired

### Monitoring Job Execution

In addition to watching the terminal windows, you can monitor job execution in several ways:

#### 1. Sidekiq Web UI or Rails Console
You can check job queues using the Rails console:
```ruby
# Rails console
Sidekiq::Queue.new.size  # Check queue size
Sidekiq::DeadSet.new.size  # Check dead jobs
```

#### 2. Redis Data Verification
Check cached session data in Rails console:
```ruby
# Rails console - check cached session data
redis_key = "check_in_lorota_v2_test-uuid-12345"
Rails.cache.read(redis_key)
```

### Testing Different Scenarios

The system supports testing various response types. You may want to test:

1. **Success Flow**: Normal BTSSS submission and SMS delivery
2. **Timeout Flow**: BTSSS timeout triggering status check job
3. **Error Flow**: BTSSS API errors triggering error notifications
4. **SMS Failures**: VA Notify service failures testing retry logic
5. **Facility Types**: Test both OH and CIE facility configurations

### Additional Debugging Tips

1. **Enable Debug Logging**:
   Set log level to debug in `config/environments/development.rb` for more detailed output:
   ```ruby
   config.log_level = :debug
   ```

2. **Check Betamocks Cache**:
   - Look in `../vets-api-mockdata` for recorded/cached responses
   - Verify response formats match expected structures

3. **Manual Job Triggering**:
   Use Rails console to manually trigger jobs:
   ```ruby
   TravelClaimSubmissionJob.perform_async(uuid, date)
   ```

4. **Network Call Verification**:
   Monitor that mock services are being called via logs

### Common Configuration Issues

Watch for these common configuration problems:

1. **Mock Response Mismatches**:
   - Jobs may fail if betamocks responses don't match expected formats
   - Check responses in `/config/betamocks/cache/`

2. **Template ID Mismatches**:
   - Ensure template IDs in `development.yml` match those referenced in job classes
   - Check VA Notify template configurations

3. **Redis Key Conflicts**:
   - Session data keys must match between LoROTA caching and job retrieval
   - Watch for key expiration timing issues

4. **Feature Flag Dependencies**:
   - Some functionality requires specific feature flags
   - Status check jobs may need additional flags enabled