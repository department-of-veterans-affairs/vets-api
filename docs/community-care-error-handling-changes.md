# Community Care Appointment Error Handling Changes

## Overview

This document outlines the changes made to standardize error handling for Community Care appointments in the VAOS V2 API. The changes introduce a unified error handler that provides consistent error responses across all Community Care appointment operations.

## New Components

### CommunityCareAppointmentErrorHandler

**Location**: `modules/vaos/app/services/vaos/v2/community_care_appointment_error_handler.rb`

A centralized service for handling all errors related to Community Care appointments (both `create_draft` and `submit_referral_appointment` endpoints). This handler:

- Normalizes error responses into a consistent format
- Maps backend service exceptions to descriptive error codes
- Provides rich metadata for debugging
- Ensures no PII is exposed in error responses
- Integrates with existing PII logging (no duplication)

### Standardized Error Response Format

All Community Care appointment errors now follow this structure:

```json
{
  "errors": [
    {
      "title": "Community Care appointment operation failed",
      "detail": "Provider not found",
      "code": "DRAFT_PROVIDER_NOT_FOUND",
      "meta": {
        "operation": "create_draft",
        "backend_service": "EPS",
        "original_status": 404
      }
    }
  ]
}
```

## Error Codes

### Draft Appointment Errors

| Error Code                       | Description                          | HTTP Status |
| -------------------------------- | ------------------------------------ | ----------- |
| `DRAFT_AUTHENTICATION_REQUIRED`  | User authentication required         | 401         |
| `DRAFT_MISSING_PARAMETERS`       | Missing required parameters          | 400         |
| `DRAFT_REFERRAL_INVALID`         | Required referral data is missing    | 422         |
| `DRAFT_APPOINTMENT_CHECK_FAILED` | Error checking existing appointments | 502         |
| `DRAFT_REFERRAL_ALREADY_USED`    | Referral is already used             | 422         |
| `DRAFT_PROVIDER_NOT_FOUND`       | Provider not found                   | 404         |
| `DRAFT_CREATION_FAILED`          | Could not create draft appointment   | 422         |
| `DRAFT_FAILED`                   | Generic draft failure                | Varies      |

### Submit Appointment Errors

| Error Code                    | Description                | HTTP Status |
| ----------------------------- | -------------------------- | ----------- |
| `SUBMIT_APPOINTMENT_CONFLICT` | Appointment already exists | 409         |
| `SUBMIT_FAILED`               | Generic submit failure     | Varies      |

### Backend Service Errors

#### EPS Service

| Error Code                | Description                   | HTTP Status |
| ------------------------- | ----------------------------- | ----------- |
| `EPS_BAD_REQUEST`         | Invalid request to EPS        | 400         |
| `EPS_NOT_FOUND`           | Resource not found in EPS     | 404         |
| `EPS_CONFLICT`            | Conflict in EPS               | 409         |
| `EPS_SERVICE_UNAVAILABLE` | EPS service unavailable (5xx) | 502         |
| `EPS_ERROR`               | Generic EPS error             | 502         |

#### VAOS Service

| Error Code                 | Description                    | HTTP Status |
| -------------------------- | ------------------------------ | ----------- |
| `VAOS_BAD_REQUEST`         | Invalid request to VAOS        | 400         |
| `VAOS_NOT_FOUND`           | Resource not found in VAOS     | 404         |
| `VAOS_CONFLICT`            | Conflict in VAOS               | 409         |
| `VAOS_SERVICE_UNAVAILABLE` | VAOS service unavailable (5xx) | 502         |
| `VAOS_ERROR`               | Generic VAOS error             | 502         |

#### CCRA Service

| Error Code                 | Description                    | HTTP Status |
| -------------------------- | ------------------------------ | ----------- |
| `CCRA_BAD_REQUEST`         | Invalid request to CCRA        | 400         |
| `CCRA_REFERRAL_NOT_FOUND`  | Referral not found in CCRA     | 404         |
| `CCRA_SERVICE_UNAVAILABLE` | CCRA service unavailable (5xx) | 502         |
| `CCRA_ERROR`               | Generic CCRA error             | 502         |

### System Errors

| Error Code                   | Description                     | HTTP Status |
| ---------------------------- | ------------------------------- | ----------- |
| `INVALID_REQUEST_PARAMETERS` | Required parameter missing      | 400         |
| `CACHE_SERVICE_UNAVAILABLE`  | Redis/cache service unavailable | 502         |
| `INVALID_ARGUMENT`           | Invalid argument provided       | 400         |
| `UNEXPECTED_ERROR`           | Unexpected error occurred       | 500         |
| `BACKEND_SERVICE_ERROR`      | Unknown backend service error   | 502         |

## Breaking Changes

### Response Structure Changes

#### Before (create_draft)

```json
{
  "errors": [
    {
      "title": "Appointment creation failed",
      "detail": "Provider not found"
    }
  ]
}
```

#### After (create_draft)

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

**Impact**: Minor - Added `code` and `meta` fields. Title changed to be more specific.

#### Before (submit_referral_appointment)

```json
{
  "errors": [
    {
      "title": "Appointment submission failed",
      "detail": "An error occurred: conflict",
      "code": "conflict"
    }
  ]
}
```

#### After (submit_referral_appointment)

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

**Impact**: Breaking - `code` format changed from lowercase string to uppercase with underscores. Title changed.

### HTTP Status Code Changes

Most status codes remain the same, but some edge cases now map more consistently:

- Backend 4xx errors (except 400, 401, 403, 404, 409, 422) now map to their original status instead of defaulting to 422
- Backend 5xx errors consistently map to 502 (Bad Gateway) instead of varying

## Migration Guide

### For API Consumers

1. **Error Code Parsing**: Update any code that parses the `code` field to handle the new uppercase-with-underscores format (e.g., `DRAFT_PROVIDER_NOT_FOUND` instead of `provider-not-found`).

2. **Error Title Matching**: If you're matching on error titles, update to the new format: `"Community Care appointment operation failed"` instead of `"Appointment creation failed"` or `"Appointment submission failed"`.

3. **Metadata Access**: The `meta` object now provides structured information. Use `meta.operation` to determine if the error is from `create_draft` or `submit`.

4. **Backend Service Identification**: For backend service errors, check `meta.backend_service` to identify which service (EPS, VAOS, CCRA) caused the error.

### Example Code Updates

#### Before

```javascript
if (error.errors[0].title === "Appointment creation failed") {
  // Handle error
}
```

#### After

```javascript
if (error.errors[0].code === "DRAFT_PROVIDER_NOT_FOUND") {
  // Handle specific error
} else if (error.errors[0].meta?.operation === "create_draft") {
  // Handle any draft creation error
}
```

## Removed Code

The following controller methods were removed as they are now handled by `CommunityCareAppointmentErrorHandler`:

- `handle_redis_error`
- `handle_appointment_creation_error`
- `appt_creation_failed_error`
- `appointment_error_status`
- `submission_error_response`

## PII Logging Integration

The error handler integrates with the existing PII logging system:

- **No duplication**: PII is logged at the source (service layer), not in the controller or error handler
- **Existing logging preserved**: All PII logging in `Eps::ProviderService` and `CreateEpsDraftAppointment` continues to work
- **No new PII exposure**: Error responses never include PII data

## Testing

Comprehensive test coverage added in:

- `modules/vaos/spec/services/vaos/v2/community_care_appointment_error_handler_spec.rb`

Tests cover:

- All business logic error scenarios
- Backend service exceptions (EPS, VAOS, CCRA)
- System errors (Redis, parameter validation, etc.)
- Edge cases (nil values, unparseable JSON, etc.)

## Rollout Recommendations

1. **Monitor Error Codes**: Track which error codes are most common to identify any unexpected behavior
2. **Update Documentation**: Ensure API documentation reflects the new error response format
3. **Client Communication**: Notify API consumers of the breaking changes, especially the `code` format change
4. **Gradual Rollout**: Consider a phased rollout if possible, starting with non-production environments

## Future Enhancements

Potential improvements for future iterations:

1. **I18n Support**: Add internationalization for error messages
2. **Error Recovery Hints**: Include suggested actions in error responses
3. **Correlation IDs**: Add request correlation IDs to error metadata for easier debugging
4. **Rate Limiting Info**: Include rate limit information in 429 responses
5. **Extend to Other Endpoints**: Apply the same pattern to non-Community Care appointment endpoints

## Questions or Issues

For questions about these changes, contact the VAOS team or file an issue in the repository.
