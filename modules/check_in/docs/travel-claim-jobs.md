# Travel Claim Jobs Documentation

## Overview

The Travel Claim system provides asynchronous processing for veteran travel reimbursement claims submitted during check-in. The system consists of three Sidekiq jobs and a callback handler that work together to submit claims to the BTSSS (Business Travel Submission Support System) API and notify veterans of the results via SMS.

### API Flow to Trigger Jobs
Before the async jobs are triggered, the following API sequence occurs:

1. **Low Risk Authentication**: POST to `check_in/v2/sessions` with `uuid`, `dob`, and `last_name` parameters
   - Validates UUID format, DOB format (YYYY-MM-DD), and last name
   - Calls LoROTA API with these credentials for authentication
   - On success, receives JWT token and stores it in encrypted cookie and Redis cache
   - Returns session permissions (`read.full` if authorized, `read.none` if not)

2. **Data Retrieval**: GET request to `/check_in/v2/patient_check_ins/{uuid}`
   - Uses stored JWT token for authorization
   - Calls LoROTA API to retrieve user session data
   - Stores appointment and user data (station number, facility type, mobile phone) in Redis cache
   - Returns appointment and demographics data to frontend

3. **Job Initiation**: POST to `check_in/v0/travel_claims` triggers `TravelClaimSubmissionJob.perform_async`
   - Validates session is still authorized using JWT token
   - Passes UUID and appointment date to the async job

The Redis-cached session data from LoROTA (station number, facility type, mobile phone) is then used by all async jobs throughout the process.

## High-Level Flow

```
Patient Check-In → TravelClaimSubmissionJob → BTSSS API → SMS Notification
                                          ↓
                                   TravelClaimStatusCheckJob (if timeout)
                                          ↓
                                   TravelClaimNotificationJob
                                          ↓
                                   VA Notify SMS Service
                                          ↓
                                   TravelClaimNotificationCallback
```

## Retry Logic & Failure Prevention Strategy

The system uses **separated retry logic** to prevent silent failures by handling different types of failures at appropriate layers:

### BTSSS API Layer (No Retries)
- `TravelClaimSubmissionJob` and `TravelClaimStatusCheckJob` both use `retry: false`
- BTSSS API failures (network issues, service errors, timeouts) are handled immediately
- Failed BTSSS calls result in error template notifications being sent to the user
- This ensures users are always notified even when the travel claim system is down

### SMS Notification Layer (12 Retries)
- `TravelClaimNotificationJob` uses `retry: 12` for VA Notify API availability issues
- When VA Notify API is responsive, it passes SMS to external service (which has its own retry logic)
- The external service handles SMS delivery and makes callbacks to vets-api va_notify module
- va_notify module callbacks trigger `TravelClaimNotificationCallback` with delivery status
- Job retries over ~24 hours if VA Notify service is down/unresponsive to give service time to recover
- After 12 failed attempts spanning 24 hours, job enters dead queue for manual re-triggering
- This separation ensures BTSSS failures don't get stuck in retry loops

### Delivery Tracking Layer (Callbacks)
- `TravelClaimNotificationCallback` tracks actual SMS delivery status from VA Notify
- Handles permanent failures (invalid numbers), temporary failures (carrier issues)
- Provides final confirmation of message delivery separate from API request success

### Logging Strategy
The system logs at multiple levels to provide complete visibility:

- **Job Initiation**: Each job logs start with UUID, appointment date, facility info
- **BTSSS Interactions**: Success/failure responses logged with response codes
- **SMS API Requests**: TravelClaimNotificationJob logs API request success/failure (not delivery)
- **Actual Delivery**: TravelClaimNotificationCallback logs real delivery status from VA Notify
- **Metrics**: StatsD metrics track success/failure rates at each layer for monitoring

This multi-layered approach ensures no failures are silent - users get notified of BTSSS issues immediately, SMS sending has appropriate retry logic, and operators have visibility into the entire pipeline.

## Components

### 1. TravelClaimSubmissionJob

**Purpose**: Primary job that submits travel claims to the BTSSS API and initiates the notification process.

**Location**: `modules/check_in/app/sidekiq/check_in/travel_claim_submission_job.rb`

**Configuration**:
- Inherits from `TravelClaimBaseJob`
- Uses default retry: false (as per retry strategy above)

**Flow**:
1. Retrieves session data from Redis (station number, facility type) that was cached during patient check-in
2. Calls BTSSS API to submit travel claim via POST request
3. Handles different response scenarios using base job response mappings:
   - **Success**: Extracts claim number from BTSSS response (`claimNumber` field) and uses success template
   - **Duplicate**: Uses duplicate template
   - **Timeout**: Schedules `TravelClaimStatusCheckJob` for 5 minutes later (if feature flag enabled)
   - **Error**: Uses error template
4. Enqueues `TravelClaimNotificationJob` with appropriate template and last four digits of claim number from BTSSS response

**Key Methods**:
- `perform(uuid, appointment_date)`: Main entry point
- `submit_claim(opts)`: Handles BTSSS API interaction
- `handle_response(opts)`: Processes API responses, takes hash with `:claims_resp` and `:facility_type`
- `should_handle_timeout(claims_resp)`: Checks if timeout should trigger status check job

### 2. TravelClaimStatusCheckJob

**Purpose**: Checks the status of travel claims that initially timed out during submission.

**Location**: `modules/check_in/app/sidekiq/check_in/travel_claim_status_check_job.rb`

**Configuration**:
- Inherits from `TravelClaimBaseJob`
- Uses default retry: false (as per retry strategy above)

**Flow**:
1. Retrieves session data from Redis
2. Calls BTSSS API to check claim status
3. Processes status response:
   - Maps claim statuses to success/failure categories using class constants
   - Handles multiple claims or empty responses
4. Enqueues `TravelClaimNotificationJob` with appropriate template

**Claim Status Categorization**:
Uses constants defined in the class (`SUCCESSFUL_CLAIM_STATUSES` and `FAILED_CLAIM_STATUSES`) to categorize BTSSS claim statuses into success/failure before mapping to response codes.

**Key Methods**:
- `perform(uuid, appointment_date)`: Main entry point
- `claim_status(opts)`: Handles BTSSS API status check interaction
- `handle_response(opts)`: Processes API responses, takes hash with `:claim_status_resp`, `:facility_type`, and `:uuid`
- `get_code_for_200_response(claim_status_resp, uuid)`: Maps claim statuses to response codes

### 3. TravelClaimNotificationJob

**Purpose**: Sends SMS notifications to veterans about their travel claim status using VA Notify.

**Location**: `modules/check_in/app/sidekiq/check_in/travel_claim_notification_job.rb`

**Configuration**:
- Inherits from `TravelClaimBaseJob`
- **retry: 12** (as per retry strategy above - gives VA Notify service 24 hours to recover)
- Required fields: `mobile_phone`, `template_id`, `appointment_date`

**Flow**:
1. Retrieves mobile phone number from Redis (cached during patient check-in flow)
2. Validates required parameters
3. Parses appointment date
4. Configures VA Notify client with callback options
5. Sends SMS with personalized content
6. Handles retries for transient failures (VA Notify service unavailability)
7. Logs success/failure and updates metrics

**Key Features**:
- **Validation**: Early return for missing required fields (prevents unnecessary retries)
- **Callback Integration**: Configures VA Notify callbacks for delivery tracking
- **Facility-Specific**: Uses different SMS sender IDs and templates for OH vs CIE facilities
- **Error Handling**: Exhausted retries trigger Sentry logging and dead queue placement

**Personalisation Data**:
- `claim_number`: Last 4 digits of claim number (via `.last(4)` operation) or "unknown"
- `appt_date`: Formatted appointment date (e.g., "May 15")

### 4. TravelClaimNotificationCallback

**Purpose**: Handles VA Notify delivery status callbacks to track actual SMS delivery success/failure.

**Location**: `modules/check_in/app/services/check_in/travel_claim_notification_callback.rb`

**Implementation**: Custom callback handler following VA Notify patterns

**Delivery Statuses Handled**:
- **delivered**: SMS successfully delivered to recipient
- **permanent-failure**: SMS delivery permanently failed (invalid number, blocked, etc.)
- **temporary-failure**: SMS delivery temporarily failed (end-state, no more retries)
- **unknown**: Unexpected status

**Key Methods**:
- `call(notification)`: Main callback entry point
- `handle_delivered`: Processes successful delivery
- `handle_permanent_failure(metadata)`: Processes permanent failures
- `handle_temporary_failure(metadata)`: Processes temporary failures
- `handle_other_status`: Processes unknown statuses

## Supporting Components

### TravelClaimBaseJob

**Purpose**: Base class providing common functionality for all travel claim jobs.

**Location**: `modules/check_in/app/sidekiq/check_in/travel_claim_base_job.rb`

**Features**:
- Sidekiq job inclusion with `retry: false` default
- Sentry logging integration
- Response code mapping constants for OH and CIE facilities (`OH_RESPONSES` and `CIE_RESPONSES` hashes)
- Template ID constants for different scenarios

**Response Mappings**:
These critical hashes map BTSSS response codes to `[StatsD_metric, SMS_template_id]` pairs:
- Maps BTSSS response codes to appropriate StatsD metrics and SMS templates
- Supports both Oracle Health (OH) and Check-In Experience (CIE) facilities
- Handles success, duplicate, timeout, and error scenarios
- Uses `Hash.new()` with default error responses
- Both `TravelClaimSubmissionJob` and `TravelClaimStatusCheckJob` use these mappings via `OH_RESPONSES` and `CIE_RESPONSES` hashes

### TravelClaimNotificationUtilities

**Purpose**: Shared utility functions for notification job and callback.

**Location**: `modules/check_in/app/services/check_in/travel_claim_notification_utilities.rb`

**Utilities**:
- `determine_facility_type_from_template(template_id)`: Maps template IDs to facility types (OH vs CIE)
- `failure_template?(template_id)`: Identifies failure notification templates vs success templates
- `increment_silent_failure_metrics(template_id, facility_type)`: Handles failure metrics with appropriate tags
- `phone_last_four(phone_number)`: Safely extracts last 4 digits from phone numbers, returns 'unknown' for nil

## Facility Types & Templates

The system supports two facility types with different SMS configurations:

### Oracle Health (OH)
- **Templates**: `OH_SUCCESS_TEMPLATE_ID`, `OH_ERROR_TEMPLATE_ID`, `OH_FAILURE_TEMPLATE_ID`, `OH_TIMEOUT_TEMPLATE_ID`, `OH_DUPLICATE_TEMPLATE_ID`
- **SMS Sender**: `OH_SMS_SENDER_ID`
- **Metrics**: Prefixed with `oracle_health`

### Check-In Experience (CIE)
- **Templates**: `CIE_SUCCESS_TEMPLATE_ID`, `CIE_ERROR_TEMPLATE_ID`, `CIE_FAILURE_TEMPLATE_ID`, `CIE_TIMEOUT_TEMPLATE_ID`, `CIE_DUPLICATE_TEMPLATE_ID`
- **SMS Sender**: `CIE_SMS_SENDER_ID`
- **Metrics**: Prefixed with `checkin`

**Template Types**:
- **Success/Duplicate**: Sent when travel claim is successfully processed
- **Failure**: Sent when claim is denied or rejected by BTSSS
- **Error**: Sent when BTSSS API errors occur or system failures happen
- **Timeout**: Sent when BTSSS API times out and status check also fails

## Local Testing

For detailed instructions on testing the travel claim async flow locally, including setup, configuration, and step-by-step testing procedures, please refer to:

`docs/locally_testing_travel_claims.md`

This guide provides comprehensive documentation for:
- Setting up required local services
- Configuring mock services and responses
- Running the test flow
- Monitoring job execution
- Troubleshooting common issues
- Testing different scenarios