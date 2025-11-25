# Oracle Health Refill Submission Metadata

## Overview

Enhanced the Oracle Health prescription data path to extract and store refill submission timing data from FHIR Task resources. This provides the same refill status visibility for Oracle Health prescriptions that VistA prescriptions already have via the `refill_submit_date` field.

**Data Source:** FHIR Task resources contained in MedicationRequest per FHIR standard (https://hl7.org/fhir/task.html)

**Implementation:** Refill metadata is extracted during prescription parsing by the `OracleHealthPrescriptionAdapter` and stored as attributes on the `Prescription` model. This data is available for use by controllers (my_health and mobile) in subsequent PRs.

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

## New Prescription Model Attributes (Oracle Health Only)

These attributes are populated during prescription parsing by the `OracleHealthPrescriptionAdapter`:

| Attribute | Type | Description | Source | Example |
|-----------|------|-------------|--------|---------|
| `refill_request_submit_date` | String (ISO 8601) | Timestamp when the refill was submitted | Task.executionPeriod.start | `"2025-06-24T21:05:53.000Z"` |
| `refill_request_status` | String | Current status of the refill request | Task.status | `"requested"`, `"in-progress"`, `"completed"`, `"failed"` |
| `refill_request_task_id` | String | Unique identifier of the Task resource | Task.id | `"1234567"` |
| `refill_request_days_since_submission` | Integer | Calculated days since submission | Calculated from Task.executionPeriod.start | `3` |

## Implementation Details

**Adapter-Level Processing:**
The `OracleHealthPrescriptionAdapter` automatically extracts refill metadata during prescription parsing:

1. `build_task_resources(resource)` - Extracts Task resources from MedicationRequest's `contained` array
2. `extract_refill_metadata_from_tasks(task_resources)` - Processes Task resources to extract metadata
3. Metadata is merged into prescription attributes during `build_prescription_attributes(resource)`

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

**Result:**
The parsed `Prescription` object will have:
- `refill_request_submit_date`: `"2025-06-24T21:05:53.000Z"`
- `refill_request_status`: `"in-progress"`
- `refill_request_task_id`: `"1234567"`
- `refill_request_days_since_submission`: `3` (calculated)

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
- `refill_request_days_since_submission` is calculated during parsing (based on current time)
- Attributes are `nil` when no Task resources exist in the prescription data

## Controller Usage (Future PR)

Controllers can access these attributes directly from the Prescription model:

```ruby
prescriptions.each do |prescription|
  if prescription.refill_request_status.present?
    # This prescription has an in-progress refill request
    submit_date = prescription.refill_request_submit_date
    status = prescription.refill_request_status
    days_since = prescription.refill_request_days_since_submission
  end
end
```

This data can be used to enhance the `recently_requested` metadata or other controller responses.
