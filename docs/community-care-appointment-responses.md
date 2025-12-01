# Community Care Appointment API Responses

## Complete Reference for Draft Creation and Appointment Submission Endpoints

This document provides a comprehensive list of all possible responses (successful and error) for the Community Care appointment endpoints in the VAOS V2 API.

---

## Table of Contents

1. [Create Draft Appointment (`POST /vaos/v2/appointments/draft`)](#create-draft-appointment)
   - [Success Response](#draft-success-response)
   - [Error Responses](#draft-error-responses)
2. [Submit Referral Appointment (`POST /vaos/v2/appointments/submit`)](#submit-referral-appointment)
   - [Success Response](#submit-success-response)
   - [Error Responses](#submit-error-responses)
3. [Error Response Structure](#error-response-structure)
4. [HTTP Status Code Reference](#http-status-code-reference)

---

## Create Draft Appointment

**Endpoint**: `POST /vaos/v2/appointments/draft`

**Request Parameters**:

- `referral_number` (required): The referral identifier
- `referral_consult_id` (required): The referral consultation identifier

### Draft Success Response

**HTTP Status**: `201 Created`

**Response Structure**:

```json
{
  "data": {
    "id": "draft-appointment-id-123",
    "type": "draft_appointment",
    "attributes": {
      "provider": {
        "id": "provider-service-id-456",
        "name": "Provider Name",
        "is_active": true,
        "individual_providers": [
          {
            "name": "Dr. John Smith",
            "npi": "1234567890"
          }
        ],
        "provider_organization": {
          "name": "Healthcare Organization",
          "tax_id": "12-3456789"
        },
        "location": {
          "address": {
            "street": "123 Main St",
            "city": "Springfield",
            "state": "IL",
            "zip": "62701"
          },
          "coordinates": {
            "latitude": 39.7817,
            "longitude": -89.6501
          }
        },
        "network_ids": ["network-123"],
        "scheduling_notes": "Please arrive 15 minutes early",
        "appointment_types": [
          {
            "id": "type-1",
            "name": "Office Visit",
            "duration": 30
          }
        ],
        "specialties": ["CARDIOLOGY"],
        "visit_mode": "IN_PERSON",
        "features": {
          "telehealth": false,
          "wheelchair_accessible": true
        }
      },
      "slots": [
        {
          "id": "slot-789",
          "start": "2024-02-15T10:00:00Z",
          "end": "2024-02-15T10:30:00Z",
          "appointment_type_id": "type-1"
        },
        {
          "id": "slot-790",
          "start": "2024-02-15T14:00:00Z",
          "end": "2024-02-15T14:30:00Z",
          "appointment_type_id": "type-1"
        }
      ],
      "drivetime": {
        "origin": {
          "address": "456 Veteran St, Springfield, IL 62702",
          "coordinates": {
            "latitude": 39.79,
            "longitude": -89.64
          }
        },
        "destination": {
          "distance": 3.2,
          "duration": 12,
          "address": "123 Main St, Springfield, IL 62701"
        }
      }
    }
  }
}
```

**Notes**:

- `slots` may be empty array if no slots are available
- `drivetime` will be `null` in mock/test environments
- `individual_providers` array contains provider details
- All timestamps are in ISO 8601 format with UTC timezone

---

### Draft Error Responses

#### 1. Authentication Required

**HTTP Status**: `401 Unauthorized`

**Trigger**: User is not authenticated

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "User authentication required",
      "code": "DRAFT_AUTHENTICATION_REQUIRED",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

---

#### 2. Missing Required Parameters

**HTTP Status**: `400 Bad Request`

**Trigger**: One or more required parameters are missing

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "Missing required parameters: referral_number, referral_consult_id",
      "code": "DRAFT_MISSING_PARAMETERS",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

**Possible Missing Parameters**:

- `referral_number`
- `referral_consult_id`
- `user.icn` (from authenticated user)

---

#### 3. Referral Data Invalid

**HTTP Status**: `422 Unprocessable Entity`

**Trigger**: Referral data is missing required fields or has invalid format

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "Required referral data is missing or incomplete: provider_npi, provider_specialty, treating_facility_address",
      "code": "DRAFT_REFERRAL_INVALID",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

**Possible Missing Referral Attributes**:

- `provider_npi`
- `provider_specialty`
- `treating_facility_address`
- `referral_number`
- `referral_type`
- `created_date`

---

#### 4. Appointment Check Failed

**HTTP Status**: `502 Bad Gateway`

**Trigger**: Error occurred while checking for existing appointments (Redis or backend service failure)

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "Error checking existing appointments: Redis connection failed",
      "code": "DRAFT_APPOINTMENT_CHECK_FAILED",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

---

#### 5. Referral Already Used

**HTTP Status**: `422 Unprocessable Entity`

**Trigger**: An appointment already exists for this referral

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "No new appointment created: referral is already used",
      "code": "DRAFT_REFERRAL_ALREADY_USED",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

---

#### 6. Provider Not Found

**HTTP Status**: `404 Not Found`

**Trigger**: No provider found matching the referral criteria (NPI, specialty, address)

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "Provider not found",
      "code": "DRAFT_PROVIDER_NOT_FOUND",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

**Common Reasons**:

- Provider NPI doesn't exist in EPS
- Provider not self-schedulable
- Provider specialty doesn't match referral
- Provider address doesn't match referral treating facility

---

#### 7. Draft Creation Failed

**HTTP Status**: `422 Unprocessable Entity`

**Trigger**: EPS service returned success but draft appointment has no ID

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "Could not create draft appointment",
      "code": "DRAFT_CREATION_FAILED",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

---

#### 8. EPS Service Errors

**HTTP Status**: Varies (400, 404, 409, 502)

**Trigger**: EPS backend service returns an error

**Bad Request (400)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "Invalid request parameters",
      "code": "EPS_BAD_REQUEST",
      "meta": {
        "operation": "create_draft",
        "backend_service": "EPS",
        "original_status": 400
      }
    }
  ]
}
```

**Not Found (404)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "Resource not found",
      "code": "EPS_NOT_FOUND",
      "meta": {
        "operation": "create_draft",
        "backend_service": "EPS",
        "original_status": 404
      }
    }
  ]
}
```

**Service Unavailable (503)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "EPS service temporarily unavailable",
      "code": "EPS_SERVICE_UNAVAILABLE",
      "meta": {
        "operation": "create_draft",
        "backend_service": "EPS",
        "original_status": 503,
        "backend_detail": "Service temporarily unavailable"
      }
    }
  ]
}
```

---

#### 9. CCRA Service Errors

**HTTP Status**: Varies (400, 404, 502)

**Trigger**: CCRA backend service returns an error when fetching referral data

**Not Found (404)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "Referral not found",
      "code": "CCRA_REFERRAL_NOT_FOUND",
      "meta": {
        "operation": "create_draft",
        "backend_service": "CCRA",
        "original_status": 404
      }
    }
  ]
}
```

**Service Unavailable (500+)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "CCRA service error",
      "code": "CCRA_SERVICE_UNAVAILABLE",
      "meta": {
        "operation": "create_draft",
        "backend_service": "CCRA",
        "original_status": 503
      }
    }
  ]
}
```

---

#### 10. Redis Cache Error

**HTTP Status**: `502 Bad Gateway`

**Trigger**: Redis connection failure during cache operations

```json
{
  "errors": [
    {
      "title": "Service temporarily unavailable",
      "detail": "Unable to connect to cache service. Please try again.",
      "code": "CACHE_SERVICE_UNAVAILABLE",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

---

#### 11. Parameter Validation Error

**HTTP Status**: `400 Bad Request`

**Trigger**: ActionController::ParameterMissing exception

```json
{
  "errors": [
    {
      "title": "Invalid request parameters",
      "detail": "Required parameter missing: referral_number",
      "code": "INVALID_REQUEST_PARAMETERS",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

---

#### 12. Unexpected Error

**HTTP Status**: `500 Internal Server Error`

**Trigger**: Any unhandled exception

```json
{
  "errors": [
    {
      "title": "Unexpected error occurred",
      "detail": "An unexpected error occurred. Please try again.",
      "code": "UNEXPECTED_ERROR",
      "meta": {
        "operation": "create_draft"
      }
    }
  ]
}
```

---

## Submit Referral Appointment

**Endpoint**: `POST /vaos/v2/appointments/{id}/submit`

**Request Parameters**:

- `id` (path parameter, required): The draft appointment ID
- `referral_number` (required): The referral number
- `network_id` (required): The network ID
- `provider_service_id` (required): The provider service ID
- `slot_id` (required): The selected slot ID
- `additional_patient_attributes` (optional): Additional patient information

### Submit Success Response

**HTTP Status**: `201 Created`

**Response Structure**:

```json
{
  "data": {
    "id": "confirmed-appointment-id-789"
  }
}
```

**Notes**:

- Response is minimal - only contains the confirmed appointment ID
- Appointment details can be retrieved via GET endpoint
- Confirmation email is sent asynchronously
- Metrics are logged for successful booking

---

### Submit Error Responses

#### 1. Appointment Already Exists (Conflict)

**HTTP Status**: `409 Conflict`

**Trigger**: Appointment already exists for this referral or slot

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "Appointment already exists",
      "code": "SUBMIT_APPOINTMENT_CONFLICT",
      "meta": {
        "operation": "submit"
      }
    }
  ]
}
```

---

#### 2. Missing Required Parameters

**HTTP Status**: `400 Bad Request`

**Trigger**: Required submission parameters are missing

```json
{
  "errors": [
    {
      "title": "Invalid request parameters",
      "detail": "Required parameter missing: slot_id",
      "code": "INVALID_REQUEST_PARAMETERS",
      "meta": {
        "operation": "submit"
      }
    }
  ]
}
```

**Required Parameters**:

- `network_id`
- `provider_service_id`
- `slot_ids` (array)
- `referral_number`
- `user.email` (from authenticated user)

---

#### 3. Invalid Argument

**HTTP Status**: `400 Bad Request`

**Trigger**: ArgumentError raised during validation

```json
{
  "errors": [
    {
      "title": "Invalid parameters",
      "detail": "ArgumentError",
      "code": "INVALID_ARGUMENT",
      "meta": {
        "operation": "submit"
      }
    }
  ]
}
```

**Common Causes**:

- `appointment_id` is blank
- User email is blank
- Invalid parameter format

---

#### 4. EPS Service Errors

**HTTP Status**: Varies (400, 404, 409, 502)

**Trigger**: EPS backend service returns an error during submission

**Bad Request (400)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "Invalid submission data",
      "code": "EPS_BAD_REQUEST",
      "meta": {
        "operation": "submit",
        "backend_service": "EPS",
        "original_status": 400
      }
    }
  ]
}
```

**Not Found (404)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "Draft appointment not found",
      "code": "EPS_NOT_FOUND",
      "meta": {
        "operation": "submit",
        "backend_service": "EPS",
        "original_status": 404
      }
    }
  ]
}
```

**Conflict (409)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "Appointment slot no longer available",
      "code": "EPS_CONFLICT",
      "meta": {
        "operation": "submit",
        "backend_service": "EPS",
        "original_status": 409
      }
    }
  ]
}
```

**Service Unavailable (503)**:

```json
{
  "errors": [
    {
      "title": "External service error",
      "detail": "EPS service temporarily unavailable",
      "code": "EPS_SERVICE_UNAVAILABLE",
      "meta": {
        "operation": "submit",
        "backend_service": "EPS",
        "original_status": 503
      }
    }
  ]
}
```

---

#### 5. Redis Cache Error

**HTTP Status**: `502 Bad Gateway`

**Trigger**: Redis connection failure during appointment data storage

```json
{
  "errors": [
    {
      "title": "Service temporarily unavailable",
      "detail": "Unable to connect to cache service. Please try again.",
      "code": "CACHE_SERVICE_UNAVAILABLE",
      "meta": {
        "operation": "submit"
      }
    }
  ]
}
```

---

#### 6. CCRA Service Error (Type of Care Fetch)

**HTTP Status**: Varies

**Trigger**: Error fetching type of care for metrics (non-blocking, logged but doesn't fail request)

**Note**: This error is caught and logged but does NOT prevent appointment submission. The submission continues with `type_of_care: 'no_value'` for metrics.

---

#### 7. Unexpected Error

**HTTP Status**: `500 Internal Server Error`

**Trigger**: Any unhandled exception during submission

```json
{
  "errors": [
    {
      "title": "Unexpected error occurred",
      "detail": "An unexpected error occurred. Please try again.",
      "code": "UNEXPECTED_ERROR",
      "meta": {
        "operation": "submit"
      }
    }
  ]
}
```

---

## Error Response Structure

All error responses follow this consistent structure:

```json
{
  "errors": [{
    "title": "Error category (human-readable)",
    "detail": "Specific error message describing what went wrong",
    "code": "MACHINE_READABLE_ERROR_CODE",
    "meta": {
      "operation": "create_draft | submit",
      "backend_service": "EPS | VAOS | CCRA (if applicable)",
      "original_status": 503 (if backend error),
      "backend_detail": "Additional backend error info (if available)"
    }
  }]
}
```

**Field Descriptions**:

- **`title`**: High-level error category

  - `"Community Care appointment operation failed"` - Business logic errors
  - `"External service error"` - Backend service errors
  - `"Invalid request parameters"` - Parameter validation errors
  - `"Service temporarily unavailable"` - Infrastructure errors
  - `"Invalid parameters"` - Argument validation errors
  - `"Unexpected error occurred"` - Unhandled exceptions

- **`detail`**: Specific, actionable error message for the user

- **`code`**: Machine-readable error code for programmatic handling

- **`meta`**: Additional context for debugging
  - `operation`: Which endpoint operation failed
  - `backend_service`: Which backend service caused the error (if applicable)
  - `original_status`: HTTP status from backend service (if applicable)
  - `backend_detail`: Additional detail from backend (if available)

---

## HTTP Status Code Reference

### Success Codes

| Status | Code    | Usage                                  |
| ------ | ------- | -------------------------------------- |
| 201    | Created | Draft appointment created successfully |
| 201    | Created | Appointment submitted successfully     |

### Client Error Codes (4xx)

| Status | Code                 | Error Codes                                                                                                                                       | Description                                    |
| ------ | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| 400    | Bad Request          | `DRAFT_MISSING_PARAMETERS`<br>`INVALID_REQUEST_PARAMETERS`<br>`INVALID_ARGUMENT`<br>`EPS_BAD_REQUEST`<br>`VAOS_BAD_REQUEST`<br>`CCRA_BAD_REQUEST` | Missing or invalid request parameters          |
| 401    | Unauthorized         | `DRAFT_AUTHENTICATION_REQUIRED`                                                                                                                   | User not authenticated                         |
| 404    | Not Found            | `DRAFT_PROVIDER_NOT_FOUND`<br>`EPS_NOT_FOUND`<br>`VAOS_NOT_FOUND`<br>`CCRA_REFERRAL_NOT_FOUND`                                                    | Resource not found                             |
| 409    | Conflict             | `SUBMIT_APPOINTMENT_CONFLICT`<br>`EPS_CONFLICT`<br>`VAOS_CONFLICT`                                                                                | Resource conflict (already exists, slot taken) |
| 422    | Unprocessable Entity | `DRAFT_REFERRAL_INVALID`<br>`DRAFT_REFERRAL_ALREADY_USED`<br>`DRAFT_CREATION_FAILED`                                                              | Request valid but cannot be processed          |

### Server Error Codes (5xx)

| Status | Code                  | Error Codes                                                                                                                                                                                                                        | Description                                   |
| ------ | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| 500    | Internal Server Error | `UNEXPECTED_ERROR`                                                                                                                                                                                                                 | Unhandled server error                        |
| 502    | Bad Gateway           | `DRAFT_APPOINTMENT_CHECK_FAILED`<br>`CACHE_SERVICE_UNAVAILABLE`<br>`EPS_SERVICE_UNAVAILABLE`<br>`VAOS_SERVICE_UNAVAILABLE`<br>`CCRA_SERVICE_UNAVAILABLE`<br>`EPS_ERROR`<br>`VAOS_ERROR`<br>`CCRA_ERROR`<br>`BACKEND_SERVICE_ERROR` | Backend service unavailable or returned error |

---

## Error Code Quick Reference

### Draft Appointment Error Codes

| Code                             | HTTP Status | Description                                  |
| -------------------------------- | ----------- | -------------------------------------------- |
| `DRAFT_AUTHENTICATION_REQUIRED`  | 401         | User not authenticated                       |
| `DRAFT_MISSING_PARAMETERS`       | 400         | Required parameters missing                  |
| `DRAFT_REFERRAL_INVALID`         | 422         | Referral data incomplete or invalid          |
| `DRAFT_APPOINTMENT_CHECK_FAILED` | 502         | Error checking existing appointments         |
| `DRAFT_REFERRAL_ALREADY_USED`    | 422         | Referral already has appointment             |
| `DRAFT_PROVIDER_NOT_FOUND`       | 404         | Provider not found or doesn't match criteria |
| `DRAFT_CREATION_FAILED`          | 422         | Draft creation returned no ID                |
| `DRAFT_FAILED`                   | Varies      | Generic draft failure                        |

### Submit Appointment Error Codes

| Code                          | HTTP Status | Description                |
| ----------------------------- | ----------- | -------------------------- |
| `SUBMIT_APPOINTMENT_CONFLICT` | 409         | Appointment already exists |
| `SUBMIT_FAILED`               | Varies      | Generic submit failure     |

### Backend Service Error Codes

| Code                       | HTTP Status | Backend | Description                    |
| -------------------------- | ----------- | ------- | ------------------------------ |
| `EPS_BAD_REQUEST`          | 400         | EPS     | Invalid request to EPS         |
| `EPS_NOT_FOUND`            | 404         | EPS     | Resource not found in EPS      |
| `EPS_CONFLICT`             | 409         | EPS     | Conflict in EPS                |
| `EPS_SERVICE_UNAVAILABLE`  | 502         | EPS     | EPS service unavailable (5xx)  |
| `EPS_ERROR`                | 502         | EPS     | Generic EPS error              |
| `VAOS_BAD_REQUEST`         | 400         | VAOS    | Invalid request to VAOS        |
| `VAOS_NOT_FOUND`           | 404         | VAOS    | Resource not found in VAOS     |
| `VAOS_CONFLICT`            | 409         | VAOS    | Conflict in VAOS               |
| `VAOS_SERVICE_UNAVAILABLE` | 502         | VAOS    | VAOS service unavailable (5xx) |
| `VAOS_ERROR`               | 502         | VAOS    | Generic VAOS error             |
| `CCRA_BAD_REQUEST`         | 400         | CCRA    | Invalid request to CCRA        |
| `CCRA_REFERRAL_NOT_FOUND`  | 404         | CCRA    | Referral not found in CCRA     |
| `CCRA_SERVICE_UNAVAILABLE` | 502         | CCRA    | CCRA service unavailable (5xx) |
| `CCRA_ERROR`               | 502         | CCRA    | Generic CCRA error             |
| `BACKEND_SERVICE_ERROR`    | 502         | Unknown | Unknown backend service error  |

### System Error Codes

| Code                         | HTTP Status | Description                        |
| ---------------------------- | ----------- | ---------------------------------- |
| `INVALID_REQUEST_PARAMETERS` | 400         | ActionController parameter missing |
| `CACHE_SERVICE_UNAVAILABLE`  | 502         | Redis/cache service unavailable    |
| `INVALID_ARGUMENT`           | 400         | ArgumentError in validation        |
| `UNEXPECTED_ERROR`           | 500         | Unhandled exception                |

---

## Response Flow Diagrams

### Draft Appointment Creation Flow

```
POST /vaos/v2/appointments/draft
    ↓
Validate Authentication
    ├─ FAIL → 401 DRAFT_AUTHENTICATION_REQUIRED
    ↓
Validate Parameters
    ├─ FAIL → 400 DRAFT_MISSING_PARAMETERS
    ↓
Fetch Referral from CCRA
    ├─ FAIL → 404 CCRA_REFERRAL_NOT_FOUND
    ├─ FAIL → 502 CCRA_SERVICE_UNAVAILABLE
    ↓
Validate Referral Data
    ├─ FAIL → 422 DRAFT_REFERRAL_INVALID
    ↓
Check Existing Appointments
    ├─ ERROR → 502 DRAFT_APPOINTMENT_CHECK_FAILED
    ├─ EXISTS → 422 DRAFT_REFERRAL_ALREADY_USED
    ↓
Find Provider in EPS
    ├─ NOT FOUND → 404 DRAFT_PROVIDER_NOT_FOUND
    ├─ FAIL → 502 EPS_SERVICE_UNAVAILABLE
    ↓
Create Draft in EPS
    ├─ NO ID → 422 DRAFT_CREATION_FAILED
    ├─ FAIL → 502 EPS_SERVICE_UNAVAILABLE
    ↓
Fetch Slots & Drive Time
    ├─ FAIL → (non-blocking, returns empty)
    ↓
SUCCESS → 201 Created with full draft data
```

### Appointment Submission Flow

```
POST /vaos/v2/appointments/{id}/submit
    ↓
Fetch Type of Care (for metrics)
    ├─ FAIL → (logged, continues with 'no_value')
    ↓
Validate Parameters
    ├─ FAIL → 400 INVALID_REQUEST_PARAMETERS
    ├─ FAIL → 400 INVALID_ARGUMENT
    ↓
Store Appointment Data in Redis
    ├─ FAIL → 502 CACHE_SERVICE_UNAVAILABLE
    ↓
Submit to EPS
    ├─ CONFLICT → 409 EPS_CONFLICT
    ├─ NOT FOUND → 404 EPS_NOT_FOUND
    ├─ FAIL → 502 EPS_SERVICE_UNAVAILABLE
    ↓
SUCCESS → 201 Created with appointment ID
```

---

## Notes

### PII Logging

- All error scenarios with referral numbers and NPIs are logged to `PersonalInformationLog` (encrypted)
- Error responses NEVER include PII data
- Logging occurs at the service layer, not in error responses

### Metrics

- Success and failure metrics are logged via StatsD
- Type of care is included in metrics when available
- Booking duration is tracked for successful submissions

### Caching

- Referral cache is cleared on successful draft creation
- Appointment data is cached in Redis for status polling
- Cache failures don't prevent appointment operations (logged and handled)

### Asynchronous Operations

- Appointment status polling job is queued after submission
- Confirmation emails are sent asynchronously
- These operations don't affect the API response

### Testing

- Mock mode disables drive time calculations
- VCR cassettes are used for testing external service calls
- All error scenarios have test coverage

---

## Version History

| Version | Date       | Changes                             |
| ------- | ---------- | ----------------------------------- |
| 1.0     | 2025-01-28 | Initial comprehensive documentation |

---

## Related Documentation

- [Community Care Error Handling Changes](./community-care-error-handling-changes.md)
- [Community Care PII Logging](./community-care-pii-logging.md)
- [Community Care Error Handling Implementation Summary](./community-care-error-handling-implementation-summary.md)
