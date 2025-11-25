# Oracle Health Refill Submission Metadata

## Overview

Enhanced the `recently_requested` metadata in MyHealth V2 Prescriptions API to include Oracle Health-specific refill submission timing data. This provides the same refill status visibility for Oracle Health prescriptions that VistA prescriptions already have.

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
        
        // Oracle Health-specific fields (only present when in-progress dispenses exist):
        "refill_submit_date": "2025-06-24T21:05:53.000Z",
        "dispense_status": "in-progress",
        "facility_name": "556-RX-MAIN-OP",
        "days_since_submission": 3
      }
    ]
  }
}
```

### VistA Prescriptions (Unchanged)

VistA prescriptions continue to work as before - no changes to their structure.

## New Fields (Oracle Health Only)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `refill_submit_date` | String (ISO 8601) | Timestamp when the refill was submitted (from most recent in-progress dispense) | `"2025-06-24T21:05:53.000Z"` |
| `dispense_status` | String | Current status of the dispense record | `"in-progress"`, `"preparation"`, `"on-hold"` |
| `facility_name` | String | Facility processing the refill | `"556-RX-MAIN-OP"` |
| `days_since_submission` | Integer | Calculated days since submission (for timeout detection) | `3` |

## Detection Logic

The system identifies Oracle Health prescriptions by:
1. Prescription has `prescription_source: "VA"`
2. Prescription lacks `refill_submit_date` at root level (not in FHIR standard)
3. Prescription has in-progress MedicationDispense records with status: `preparation`, `in-progress`, or `on-hold`

## Frontend Usage Examples

### Check for Long-Running Refills

```javascript
const recentlyRequested = response.meta.recently_requested;

recentlyRequested.forEach(rx => {
  if (rx.days_since_submission && rx.days_since_submission > 5) {
    // Show alert: "Your refill is taking longer than expected"
    showAlert({
      title: `Refill for ${rx.prescription_name} is processing`,
      message: `Submitted ${rx.days_since_submission} days ago at ${rx.facility_name}. Status: ${rx.dispense_status}`
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
      status: existingRequest.dispense_status
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
- Metadata is extracted from MedicationDispense `whenHandedOver` field (most recent in-progress dispense)
- `days_since_submission` is calculated at request time (not stored)
- Fields only appear when relevant data exists in the dispense records
