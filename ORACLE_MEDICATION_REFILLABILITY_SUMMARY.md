# Oracle Health Medication Refillability - Technical Summary

## Overview

This document provides a comprehensive analysis of how the refillability of Oracle Health (formerly Cerner) medications is determined in the vets-api codebase, specifically within the `lib/unified_health_data` module.

## Location

The primary logic is located in:
- **File**: `lib/unified_health_data/adapters/oracle_health_prescription_adapter.rb`
- **Method**: `extract_is_refillable` (lines 204-219)
- **Supporting Methods**: 
  - `extract_refill_remaining` (lines 116-131)
  - `prescription_not_expired?` (lines 275-290)
  - `non_va_med?` (lines 271-273)

## Data Source

Oracle Health prescriptions are received as **FHIR R4 MedicationRequest resources** from the Oracle Health API endpoint. These FHIR-compliant resources contain structured medication data that must be parsed and evaluated to determine refillability.

## Refillability Determination Algorithm

The `extract_is_refillable` method implements a **multi-condition check** where ALL of the following conditions must be TRUE for a prescription to be considered refillable:

```ruby
def extract_is_refillable(resource)
  refillable = true

  # non VA meds are never refillable
  refillable = false if non_va_med?(resource)
  # must be active
  refillable = false unless resource['status'] == 'active'
  # must not be expired
  refillable = false unless prescription_not_expired?(resource)
  # must have refills remaining
  refillable = false unless extract_refill_remaining(resource).positive?
  # must have at least one dispense record
  refillable = false if find_most_recent_medication_dispense(resource['contained']).nil?

  refillable
end
```

### Condition 1: Must Be a VA Medication

**Field Checked**: `resource['reportedBoolean']`

**Logic**:
- If `reportedBoolean == true`, the medication is a **non-VA medication** (reported by patient)
- Non-VA medications are **NEVER refillable** through the VA system
- Returns `false` immediately if this condition fails

**Code Reference**:
```ruby
def non_va_med?(resource)
  resource['reportedBoolean'] == true
end
```

**Test Coverage**: Lines 505-513 in spec file

---

### Condition 2: Must Have Active Status

**Field Checked**: `resource['status']`

**Logic**:
- The FHIR MedicationRequest status must be exactly `'active'`
- Other statuses (e.g., `'completed'`, `'stopped'`, `'cancelled'`, `nil`) are **NOT refillable**
- This represents the prescription's current lifecycle state in the system

**Possible FHIR Status Values**:
- `active` - Prescription is currently active ✅ (REFILLABLE)
- `completed` - Prescription has been completed ❌
- `stopped` - Prescription was stopped ❌
- `cancelled` - Prescription was cancelled ❌
- `null/missing` - Invalid state ❌

**Test Coverage**: Lines 515-533 in spec file

---

### Condition 3: Must Not Be Expired

**Field Checked**: `resource.dig('dispenseRequest', 'validityPeriod', 'end')`

**Logic**:
- Extracts the expiration date from the FHIR resource
- If **no expiration date** exists, returns `false` as a **safety default**
- Parses the expiration date and compares to current time
- Must be **greater than** current time (`Time.zone.now`)
- Invalid or unparseable dates return `false` and log a warning

**Code Reference**:
```ruby
def prescription_not_expired?(resource)
  expiration_date = extract_expiration_date(resource)
  return false unless expiration_date # No expiration date = not refillable for safety

  begin
    parsed_date = Time.zone.parse(expiration_date)
    return parsed_date&.> Time.zone.now if parsed_date

    # If we get here, parsing returned nil (invalid date)
    log_invalid_expiration_date(resource, expiration_date)
    false
  rescue ArgumentError
    log_invalid_expiration_date(resource, expiration_date)
    false
  end
end
```

**Safety Features**:
- Missing expiration date → Not refillable (conservative approach)
- Invalid date format → Not refillable + logged warning
- Parse exceptions → Not refillable + logged warning

**Test Coverage**: Lines 535-585 in spec file

---

### Condition 4: Must Have Refills Remaining

**Field Checked**: 
- `resource.dig('dispenseRequest', 'numberOfRepeatsAllowed')` 
- `resource['contained']` (MedicationDispense resources)

**Logic**: This is the most complex condition with the following calculation:

```ruby
def extract_refill_remaining(resource)
  # non-va meds are never refillable
  return 0 if non_va_med?(resource)

  repeats_allowed = resource.dig('dispenseRequest', 'numberOfRepeatsAllowed') || 0
  
  # subtract dispenses in completed status, except for the first fill
  dispenses_completed = if resource['contained']
                          resource['contained'].count do |c|
                            c['resourceType'] == 'MedicationDispense' && c['status'] == 'completed'
                          end
                        else
                          0
                        end
  
  remaining = repeats_allowed - [dispenses_completed - 1, 0].max
  remaining.positive? ? remaining : 0
end
```

**Calculation Formula**:
```
remaining_refills = numberOfRepeatsAllowed - (completed_dispenses - 1)
```

**Key Insights**:
1. **Initial Fill Exception**: The first completed dispense (initial fill) does NOT count against refills
2. **Only Completed Dispenses Count**: Only dispenses with status `'completed'` reduce refill count
3. **Non-VA Medications**: Always return 0 refills regardless of FHIR data
4. **Floor at Zero**: Negative values are converted to 0 (handles over-dispensed scenarios)

**Examples**:

| numberOfRepeatsAllowed | Completed Dispenses | Calculation | Refills Remaining |
|------------------------|---------------------|-------------|-------------------|
| 5 | 0 | 5 - (0-1).max(0) = 5 - 0 | **5** |
| 5 | 1 | 5 - (1-1).max(0) = 5 - 0 | **5** (initial fill) |
| 5 | 2 | 5 - (2-1).max(0) = 5 - 1 | **4** |
| 5 | 3 | 5 - (3-1).max(0) = 5 - 2 | **3** |
| 2 | 3 | 2 - (3-1).max(0) = 2 - 2 | **0** |
| 1 | 3 | 1 - (3-1).max(0) = 1 - 2 = -1 → 0 | **0** (over-dispensed) |

**Test Coverage**: Lines 718-981 in spec file (extensive test scenarios)

---

### Condition 5: Must Have At Least One Dispense Record

**Field Checked**: `resource['contained']` array

**Logic**:
- Searches for at least one `MedicationDispense` resource in the contained array
- Uses `find_most_recent_medication_dispense` helper method
- If **no dispense records exist**, the prescription is **NOT refillable**
- This ensures prescriptions have been initially dispensed before allowing refills

**Code Reference**:
```ruby
def find_most_recent_medication_dispense(contained_resources)
  return nil unless contained_resources.is_a?(Array)

  dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }
  return nil if dispenses.empty?

  # Sort by whenHandedOver date, most recent first
  dispenses.max_by do |dispense|
    when_handed_over = dispense['whenHandedOver']
    when_handed_over ? Time.zone.parse(when_handed_over) : Time.zone.at(0)
  end
end
```

**Rationale**: A prescription must have been dispensed at least once before it can be refilled. This prevents refills on prescriptions that have never been picked up or fulfilled.

**Test Coverage**: Implicit in various test scenarios throughout spec file

---

## Complete Refillability Decision Tree

```
START: Is prescription refillable?
│
├─ Is reportedBoolean == true? (Non-VA med?)
│  ├─ YES → ❌ NOT REFILLABLE (Non-VA medication)
│  └─ NO → Continue
│
├─ Is status == 'active'?
│  ├─ NO → ❌ NOT REFILLABLE (Inactive prescription)
│  └─ YES → Continue
│
├─ Does prescription have expiration date?
│  ├─ NO → ❌ NOT REFILLABLE (Safety default)
│  └─ YES → Is expiration_date > now?
│     ├─ NO → ❌ NOT REFILLABLE (Expired)
│     └─ YES → Continue
│
├─ Are refills remaining > 0?
│  ├─ NO → ❌ NOT REFILLABLE (No refills left)
│  └─ YES → Continue
│
├─ Does prescription have at least one dispense record?
│  ├─ NO → ❌ NOT REFILLABLE (Never dispensed)
│  └─ YES → ✅ REFILLABLE
```

---

## FHIR Resource Structure

The Oracle Health adapter expects FHIR MedicationRequest resources with this structure:

```json
{
  "resourceType": "MedicationRequest",
  "id": "12345",
  "status": "active",
  "reportedBoolean": false,
  "authoredOn": "2025-01-29T19:41:43Z",
  "medicationCodeableConcept": {
    "text": "Test Medication"
  },
  "dispenseRequest": {
    "numberOfRepeatsAllowed": 5,
    "validityPeriod": {
      "end": "2025-12-31T23:59:59Z"
    },
    "quantity": {
      "value": 30
    }
  },
  "contained": [
    {
      "resourceType": "MedicationDispense",
      "id": "dispense-1",
      "status": "completed",
      "whenHandedOver": "2025-01-15T10:00:00Z",
      "location": {
        "display": "556-RX-MAIN-OP"
      }
    }
  ]
}
```

---

## Key Design Decisions

### 1. Conservative Safety Defaults
- **Missing expiration dates** → Not refillable
- **Invalid dates** → Not refillable with logged warnings
- **Negative refill calculations** → Floor at 0

**Rationale**: Protects veterans from receiving medications they shouldn't by erring on the side of caution.

### 2. Initial Fill Exception
- The first completed dispense doesn't count against refills
- Only subsequent dispenses reduce the refill count

**Rationale**: Aligns with real-world pharmacy practice where the initial fill is separate from refills.

### 3. Non-VA Medication Exclusion
- Patient-reported medications (`reportedBoolean: true`) cannot be refilled through VA
- Returns 0 refills and false for refillability regardless of other conditions

**Rationale**: VA can only refill prescriptions it has issued and manages.

### 4. Must Be Dispensed Once
- Requires at least one MedicationDispense record before allowing refills
- Prevents refills on prescriptions never picked up

**Rationale**: Ensures veterans have received the medication at least once before requesting refills.

### 5. Only Completed Dispenses Count
- Only dispenses with `status: 'completed'` reduce refill count
- In-progress, cancelled, or other statuses are ignored

**Rationale**: Only fulfilled dispenses should count against the refill allowance.

---

## Error Handling

### Graceful Degradation
- If parsing fails, the adapter returns `nil` and logs the error (line 16-18)
- Individual field extraction failures don't crash the entire parse operation
- Invalid dates are logged but don't throw exceptions

### Logging Strategy
- Invalid expiration dates trigger warnings with prescription ID context
- Parse errors are logged at ERROR level with error messages
- No PII/PHI data is included in logs (complies with healthcare privacy requirements)

---

## Test Coverage

The test suite (`spec/lib/unified_health_data/adapters/oracle_health_prescription_adapter_spec.rb`) includes comprehensive scenarios:

### Refillability Tests (lines 477-651)
- ✅ All conditions met → refillable
- ✅ Non-VA medications → not refillable
- ✅ Inactive status → not refillable
- ✅ Null status → not refillable
- ✅ Expired prescription → not refillable
- ✅ No expiration date → not refillable (safety)
- ✅ Invalid expiration date → not refillable with warning
- ✅ No refills remaining → not refillable
- ✅ Multiple failing conditions → not refillable
- ✅ Exactly one refill remaining → refillable

### Refill Remaining Tests (lines 718-981)
- ✅ Non-VA medication → 0 refills
- ✅ No dispenses → full refills available
- ✅ One dispense (initial fill) → full refills (doesn't count)
- ✅ Multiple dispenses → correct subtraction
- ✅ All refills used → 0 refills
- ✅ Over-dispensed → 0 refills (floor at zero)
- ✅ Mixed statuses → only completed count
- ✅ No numberOfRepeatsAllowed → defaults to 0
- ✅ No dispenseRequest → defaults to 0
- ✅ No contained resources → full refills
- ✅ Non-MedicationDispense resources → ignored

---

## Integration Points

### Input
- **Source**: Oracle Health FHIR API (`/v1/medicalrecords/medications`)
- **Format**: FHIR R4 Bundle with MedicationRequest entries
- **Authentication**: OAuth tokens with ICN-based patient identification

### Output
- **Model**: `UnifiedHealthData::Prescription` (lines 1-36 in models/prescription.rb)
- **Field**: `is_refillable` (Boolean attribute, line 23)
- **Serializer**: `UnifiedHealthData::Serializers::PrescriptionSerializer` (line 24)

### Consumer
- Mobile API endpoints via `Mobile::V0::PrescriptionsSerializer`
- VA.gov web application prescription management features
- Prescription refill submission workflows

---

## Related Files

- **Adapter**: `lib/unified_health_data/adapters/oracle_health_prescription_adapter.rb`
- **Model**: `lib/unified_health_data/models/prescription.rb`
- **Serializer**: `lib/unified_health_data/serializers/prescription_serializer.rb`
- **Tests**: `spec/lib/unified_health_data/adapters/oracle_health_prescription_adapter_spec.rb`
- **Service**: `lib/unified_health_data/service.rb` (orchestrates adapter usage)
- **Documentation**: `lib/unified_health_data/README.md`

---

## Summary

The refillability of Oracle Health medications is determined through a **strict AND-based evaluation** of five critical conditions:

1. **Must be a VA medication** (not patient-reported)
2. **Must have active status** in the system
3. **Must not be expired** based on validityPeriod.end
4. **Must have remaining refills** calculated from numberOfRepeatsAllowed minus used refills
5. **Must have at least one completed dispense** record

All five conditions must evaluate to TRUE for `is_refillable` to be `true`. This conservative approach ensures veterans can only refill prescriptions that are:
- Managed by the VA
- Currently active
- Not yet expired
- Have available refills
- Have been initially dispensed

The implementation prioritizes **safety and compliance** through defensive programming, comprehensive error handling, and alignment with FHIR R4 standards.
