# Oracle Health Refill Submission Metadata

## Overview

Enhanced the `recently_requested` metadata in MyHealth V2 Prescriptions API to include Oracle Health-specific refill submission timing data extracted from FHIR Task resources. This provides the same refill status visibility for Oracle Health prescriptions that VistA prescriptions already have.

**Data Source:** FHIR Task resources contained in MedicationRequest per FHIR standard (https://hl7.org/fhir/task.html)

## API Response Structure

### Before Enhancement

```json
{
  "data": [...],
  "meta": {
    "recently_requested": [
      {
        "prescription_id": "15214174591",
        "prescription_name": "albuterol",
        "disp_status": "Active: Refill in Process",
        "station_number": "556"
      }
    ]
  }
}
```

### After Enhancement (Oracle Health Prescriptions)

```json
{
  "data": [...],
  "meta": {
    "recently_requested": [
      {
        "prescription_id": "15214174591",
        "prescription_name": "albuterol",
        "disp_status": "Active: Refill in Process",
        "station_number": "556",
        
        // Oracle Health-specific fields (from FHIR Task resources):
        "refill_submit_date": "2025-06-24T21:05:53.000Z",
        "refill_request_status": "in-progress",
        "task_id": "1234567",
        "days_since_submission": 3
      }
    ]
  }
}
```

### VistA Prescriptions (Unchanged)

VistA prescriptions continue to work as before - no changes to their structure.

## New Fields (Oracle Health Only)

| Field | Type | Description | Source | Example |
|-------|------|-------------|--------|---------|
| `refill_submit_date` | String (ISO 8601) | Timestamp when the refill was submitted | Task.executionPeriod.start | `"2025-06-24T21:05:53.000Z"` |
| `refill_request_status` | String | Current status of the refill request | Task.status | `"requested"`, `"in-progress"`, `"completed"`, `"failed"` |
| `task_id` | String | Unique identifier of the Task resource | Task.id | `"1234567"` |
| `days_since_submission` | Integer | Calculated days since submission (for timeout detection) | Calculated from Task.executionPeriod.start | `3` |

## Detection Logic

The system identifies Oracle Health prescriptions by:
1. Prescription has `prescription_source: "VA"`
2. Prescription lacks `refill_submit_date` at root level (not in FHIR standard)
3. Prescription contains Task resources in the MedicationRequest's `contained` array

**FHIR Structure:**
```json
{
  "resourceType": "MedicationRequest",
  "id": "15214174591",
  "contained": [
    {
      "resourceType": "Task",
      "id": "1234567",
      "status": "in-progress",
      "executionPeriod": {
        "start": "2025-06-24T21:05:53.000Z"
      }
    }
  ]
}
```

## Frontend Usage Examples

### Check for Long-Running Refills

```javascript
const recentlyRequested = response.meta.recently_requested;

recentlyRequested.forEach(rx => {
  if (rx.days_since_submission && rx.days_since_submission > 5) {
    // Show alert: "Your refill is taking longer than expected"
    showAlert({
      title: `Refill for ${rx.prescription_name} is processing`,
      message: `Submitted ${rx.days_since_submission} days ago. Status: ${rx.refill_request_status}`
    });
  }
});
```

### Prevent Duplicate Refill Requests

```javascript
function canRequestRefill(prescriptionId) {
  const recentlyRequested = response.meta.recently_requested;
  const existingRequest = recentlyRequested.find(
    rx => rx.prescription_id === prescriptionId
  );
  
  if (existingRequest && existingRequest.refill_submit_date) {
    return {
      canRefill: false,
      reason: `Refill submitted ${existingRequest.days_since_submission} days ago`,
      status: existingRequest.refill_request_status
    };
  }
  
  return { canRefill: true };
}
```

## Backward Compatibility

- Existing frontend code will continue to work
- New fields are optional - only present for Oracle Health prescriptions with in-progress dispenses
- VistA prescriptions maintain their existing structure
- No changes to prescription attributes in the main `data` array

## Testing

All existing tests pass, plus new test added:
- `includes Oracle Health refill metadata in recently_requested for in-progress prescriptions`

## API Endpoints Affected

- `GET /my_health/v2/prescriptions` - Main prescription list
- `GET /my_health/v2/prescriptions/list_refillable_prescriptions` - Refillable prescriptions list

## Notes

- This enhancement is **Oracle Health-specific** - VistA prescriptions are not affected
- Metadata is extracted from FHIR Task resources contained in MedicationRequest
- Task resources follow FHIR standard: https://hl7.org/fhir/task.html
- `Task.status` indicates refill request outcome (requested, in-progress, completed, failed, etc.)
- `Task.executionPeriod.start` provides submission timestamp
- `days_since_submission` is calculated at request time (not stored)
- Fields only appear when Task resources exist in the prescription data
