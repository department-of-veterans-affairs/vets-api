# Oracle Health Prescription Status Normalization Implementation Plan

## Overview

Normalize Oracle Health (Cerner) FHIR MedicationRequest statuses to VistA-compatible status values in the Unified Health Data (UHD) service. This enables the mobile app to consume Oracle Health prescriptions without code changes, using the established VistA status vocabulary.

**Branch:** `feature/uhd-prescriptions-additional-fields`  
**Estimated Effort:** 1-2 days  
**Risk Level:** Low-Medium (changes adapter behavior for Oracle Health only, VistA unaffected)

---

## Problem Statement

Currently, Oracle Health prescriptions return FHIR-standard statuses (`active`, `completed`, `cancelled`, etc.) while VistA prescriptions return legacy statuses (`activeParked`, `providerHold`, `refillinprocess`, etc.). The mobile app logic is built around VistA status values, requiring normalization of Oracle Health statuses to maintain compatibility.

### Current State
- **VistA prescriptions:** Return statuses like `active`, `activeParked`, `providerHold`, `refillinprocess`, `discontinued`, `expired`
- **Oracle Health prescriptions:** Return FHIR statuses like `active`, `completed`, `cancelled`, `stopped`, `on-hold`, `draft`
- **Mobile app:** Expects VistA status values (see `status_meta` method checking for `activeParked`, `providerHold`, etc.)

### Desired State
- Oracle Health prescriptions mapped to VistA-equivalent statuses using business rules
- Mobile app requires zero changes
- VistA prescriptions unaffected
- Transparent to API consumers

---

## Business Rules Mapping

Based on the provided status mapping document, Oracle Health statuses should be normalized as follows:

### Mapping Decision Tree

| MedicationRequest.status | Refills Remaining | Expiration Date | Any Dispense Status | Normalized VistA Status |
|--------------------------|-------------------|-----------------|---------------------|-------------------------|
| `active` | Any | > 6 months ago | Any | `discontinued` |
| `active` | 0 | < 6 months ago | Any | `expired` |
| `active` | > 0 | Not expired | `preparation`, `in-progress`, or `on-hold` | `refillinprocess` |
| `active` | > 0 | Not expired | Other | `active` |
| `on-hold` | Any | Any | Any | `providerHold` |
| `cancelled` | Any | Any | Any | `discontinued` |
| `completed` | Any | ≤ 6 months ago | Any | `expired` |
| `completed` | Any | > 6 months ago | Any | `discontinued` |
| `entered-in-error` | Any | Any | Any | `discontinued` |
| `stopped` | Any | Any | Any | `discontinued` |
| `draft` | Any | Any | Any | `pending` |
| `unknown` | Any | Any | Any | `unknown` |

### Key Mapping Rules

1. **Expiration determines discontinued vs expired:**
   - If validity ended > 6 months ago → `discontinued`
   - If all refills used but recent → `expired`

2. **In-progress refills:**
   - If ANY dispense has status `preparation`, `in-progress`, or `on-hold` → `refillinprocess`

3. **Date handling:**
   - All dates in UTC/Zulu time
   - "Not expired" = `validityPeriod.end` > current time (UTC)
   - "< 6 months ago" = within last 180 days

4. **Refills remaining:**
   - Use existing `extract_refill_remaining` calculation (already handles completed dispenses correctly)

---

## Implementation Approach

### Location: `lib/unified_health_data/adapters/oracle_health_prescription_adapter.rb`

Modify the adapter to normalize status during parsing, before the Prescription model is created.

### Architecture Decision: Adapter-Level Transformation

**Rationale:**
- Single source of truth for all API consumers
- VistA prescriptions remain unchanged
- Clean separation of concerns
- Consistent behavior across mobile v1, v2, and web
- Easier to test in isolation

**Alternatives Considered:**
- ❌ Controller-level transformation: Would require duplication across controllers, violates SRP
- ❌ Serializer-level transformation: Too late in the pipeline, would affect caching

---

## Implementation Details

### 1. Modify Oracle Health Adapter

**File:** `lib/unified_health_data/adapters/oracle_health_prescription_adapter.rb`

#### Changes to `build_core_attributes` method:

```ruby
def build_core_attributes(resource)
  {
    id: resource['id'],
    type: 'Prescription',
    refill_status: extract_refill_status(resource), # ← Modified
    # ... rest unchanged
  }
end
```

#### New method: `extract_refill_status`

```ruby
# Extracts and normalizes MedicationRequest status to VistA-compatible values
#
# @param resource [Hash] FHIR MedicationRequest resource
# @return [String] VistA-compatible status value
def extract_refill_status(resource)
  normalize_to_vahb_status(resource)
end
```

#### New method: `normalize_to_vahb_status`

```ruby
# Maps Oracle Health FHIR MedicationRequest status to VistA-equivalent status
# Based on VAHB status mapping requirements
#
# @param resource [Hash] FHIR MedicationRequest resource
# @return [String] VistA-compatible status value
def normalize_to_vahb_status(resource)
  mr_status = resource['status']
  refills_remaining = extract_refill_remaining(resource)
  expiration_date = parse_expiration_date_utc(resource)
  has_in_progress_dispense = any_dispense_in_progress?(resource)
  
  # Log transformation for monitoring and validation
  normalized_status = case mr_status
  when 'active'
    normalize_active_status(refills_remaining, expiration_date, has_in_progress_dispense)
  when 'on-hold'
    'providerHold'
  when 'cancelled', 'entered-in-error', 'stopped'
    'discontinued'
  when 'completed'
    normalize_completed_status(expiration_date)
  when 'draft'
    'pending'
  when 'unknown'
    'unknown'
  else
    # Fallback for unexpected statuses
    Rails.logger.warn("Unexpected MedicationRequest status: #{mr_status}")
    'active'
  end
  
  Rails.logger.info(
    message: 'Oracle Health status normalized',
    prescription_id: resource['id'],
    original_status: mr_status,
    normalized_status: normalized_status,
    refills_remaining: refills_remaining,
    has_in_progress_dispense: has_in_progress_dispense,
    service: 'unified_health_data'
  )
  
  normalized_status
end
```

#### New method: `normalize_active_status`

```ruby
# Determines VistA status for 'active' MedicationRequest based on business rules
#
# @param refills_remaining [Integer] Number of refills remaining
# @param expiration_date [Time, nil] Parsed UTC expiration date
# @param has_in_progress_dispense [Boolean] Whether any dispense is in-progress
# @return [String] VistA status value
def normalize_active_status(refills_remaining, expiration_date, has_in_progress_dispense)
  # Rule: Expired more than 6 months ago → discontinued
  if expiration_date && expiration_date < 6.months.ago.utc
    return 'discontinued'
  end
  
  # Rule: No refills remaining → expired
  if refills_remaining.zero?
    return 'expired'
  end
  
  # Rule: Has in-progress dispense → refillinprocess
  if has_in_progress_dispense
    return 'refillinprocess'
  end
  
  # Default: active
  'active'
end
```

#### New method: `normalize_completed_status`

```ruby
# Determines VistA status for 'completed' MedicationRequest
#
# @param expiration_date [Time, nil] Parsed UTC expiration date
# @return [String] VistA status value ('expired' or 'discontinued')
def normalize_completed_status(expiration_date)
  if expiration_date && expiration_date < 6.months.ago.utc
    'expired'
  else
    'discontinued'
  end
end
```

#### New method: `any_dispense_in_progress?`

```ruby
# Checks if any MedicationDispense has an in-progress status
# In-progress statuses: preparation, in-progress, on-hold
#
# @param resource [Hash] FHIR MedicationRequest resource
# @return [Boolean] True if any dispense is in-progress
def any_dispense_in_progress?(resource)
  contained = resource['contained'] || []
  dispenses = contained.select { |c| c['resourceType'] == 'MedicationDispense' }
  
  in_progress_statuses = %w[preparation in-progress on-hold]
  
  dispenses.any? do |dispense|
    in_progress_statuses.include?(dispense['status'])
  end
end
```

#### New method: `parse_expiration_date_utc`

```ruby
# Parses validityPeriod.end to UTC Time object for comparison
#
# @param resource [Hash] FHIR MedicationRequest resource
# @return [Time, nil] Parsed UTC time or nil if not available/invalid
def parse_expiration_date_utc(resource)
  expiration_string = resource.dig('dispenseRequest', 'validityPeriod', 'end')
  return nil if expiration_string.blank?
  
  # Oracle Health dates are in Zulu time (UTC)
  Time.zone.parse(expiration_string)&.utc
rescue ArgumentError => e
  Rails.logger.warn("Failed to parse expiration date '#{expiration_string}': #{e.message}")
  nil
end
```



---

## Testing Strategy

### Unit Tests: Oracle Health Adapter

**File:** `spec/lib/unified_health_data/adapters/oracle_health_prescription_adapter_spec.rb`

Add comprehensive test coverage for all mapping scenarios:

```ruby
describe '#normalize_to_vahb_status' do
  let(:base_resource) do
    {
      'id' => 'test-123',
      'status' => 'active',
      'dispenseRequest' => {
        'numberOfRepeatsAllowed' => 3,
        'validityPeriod' => { 'end' => 1.year.from_now.utc.iso8601 }
      },
      'contained' => []
    }
  end

  context 'when MedicationRequest status is active' do
    it 'returns "discontinued" when expired more than 6 months ago' do
      resource = base_resource.merge(
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => 7.months.ago.utc.iso8601 }
        }
      )
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('discontinued')
    end
    
    it 'returns "expired" when no refills remaining' do
      resource = base_resource.merge(
        'dispenseRequest' => { 'numberOfRepeatsAllowed' => 0 },
        'contained' => []
      )
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('expired')
    end
    
    it 'returns "refillinprocess" when any dispense is preparation' do
      resource = base_resource.merge(
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'preparation'
          }
        ]
      )
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('refillinprocess')
    end
    
    it 'returns "refillinprocess" when any dispense is in-progress' do
      resource = base_resource.merge(
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed'
          },
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'in-progress'
          }
        ]
      )
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('refillinprocess')
    end
    
    it 'returns "refillinprocess" when any dispense is on-hold' do
      resource = base_resource.merge(
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'on-hold'
          }
        ]
      )
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('refillinprocess')
    end
    
    it 'returns "active" when no special conditions apply' do
      result = subject.send(:normalize_to_vahb_status, base_resource)
      expect(result).to eq('active')
    end
  end
  
  context 'when MedicationRequest status is on-hold' do
    it 'returns "providerHold"' do
      resource = base_resource.merge('status' => 'on-hold')
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('providerHold')
    end
  end
  
  context 'when MedicationRequest status is cancelled' do
    it 'returns "discontinued"' do
      resource = base_resource.merge('status' => 'cancelled')
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('discontinued')
    end
  end
  
  context 'when MedicationRequest status is completed' do
    it 'returns "expired" when expired more than 6 months ago' do
      resource = base_resource.merge(
        'status' => 'completed',
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => 7.months.ago.utc.iso8601 }
        }
      )
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('expired')
    end
    
    it 'returns "discontinued" when expired less than 6 months ago' do
      resource = base_resource.merge(
        'status' => 'completed',
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => 3.months.ago.utc.iso8601 }
        }
      )
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('discontinued')
    end
  end
  
  context 'when MedicationRequest status is entered-in-error' do
    it 'returns "discontinued"' do
      resource = base_resource.merge('status' => 'entered-in-error')
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('discontinued')
    end
  end
  
  context 'when MedicationRequest status is stopped' do
    it 'returns "discontinued"' do
      resource = base_resource.merge('status' => 'stopped')
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('discontinued')
    end
  end
  
  context 'when MedicationRequest status is draft' do
    it 'returns "pending"' do
      resource = base_resource.merge('status' => 'draft')
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('pending')
    end
  end
  
  context 'when MedicationRequest status is unknown' do
    it 'returns "unknown"' do
      resource = base_resource.merge('status' => 'unknown')
      
      result = subject.send(:normalize_to_vahb_status, resource)
      expect(result).to eq('unknown')
    end
  end
end

describe '#any_dispense_in_progress?' do
  it 'returns true when a dispense has preparation status' do
    resource = {
      'contained' => [
        { 'resourceType' => 'MedicationDispense', 'status' => 'preparation' }
      ]
    }
    
    expect(subject.send(:any_dispense_in_progress?, resource)).to be true
  end
  
  it 'returns true when a dispense has in-progress status' do
    resource = {
      'contained' => [
        { 'resourceType' => 'MedicationDispense', 'status' => 'in-progress' }
      ]
    }
    
    expect(subject.send(:any_dispense_in_progress?, resource)).to be true
  end
  
  it 'returns true when a dispense has on-hold status' do
    resource = {
      'contained' => [
        { 'resourceType' => 'MedicationDispense', 'status' => 'on-hold' }
      ]
    }
    
    expect(subject.send(:any_dispense_in_progress?, resource)).to be true
  end
  
  it 'returns false when all dispenses are completed' do
    resource = {
      'contained' => [
        { 'resourceType' => 'MedicationDispense', 'status' => 'completed' },
        { 'resourceType' => 'MedicationDispense', 'status' => 'completed' }
      ]
    }
    
    expect(subject.send(:any_dispense_in_progress?, resource)).to be false
  end
  
  it 'returns false when no dispenses exist' do
    resource = { 'contained' => [] }
    
    expect(subject.send(:any_dispense_in_progress?, resource)).to be false
  end
end

describe '#parse_expiration_date_utc' do
  it 'parses valid ISO8601 date to UTC time' do
    resource = {
      'dispenseRequest' => {
        'validityPeriod' => { 'end' => '2025-12-31T23:59:59Z' }
      }
    }
    
    result = subject.send(:parse_expiration_date_utc, resource)
    expect(result).to be_a(Time)
    expect(result.zone).to eq('UTC')
  end
  
  it 'returns nil when expiration date is missing' do
    resource = { 'dispenseRequest' => {} }
    
    result = subject.send(:parse_expiration_date_utc, resource)
    expect(result).to be_nil
  end
  
  it 'returns nil and logs warning for invalid date' do
    resource = {
      'dispenseRequest' => {
        'validityPeriod' => { 'end' => 'invalid-date' }
      }
    }
    
    expect(Rails.logger).to receive(:warn).with(/Failed to parse expiration date/)
    
    result = subject.send(:parse_expiration_date_utc, resource)
    expect(result).to be_nil
  end
end
```

### Integration Tests: Service

**File:** `spec/lib/unified_health_data/service_spec.rb`

Test end-to-end with feature flag:

```ruby
describe '#get_prescriptions with Oracle Health status normalization' do
  it 'normalizes Oracle Health statuses to VistA equivalents' do
    VCR.use_cassette('uhd/get_prescriptions_oracle_health') do
      prescriptions = subject.get_prescriptions
      
      oracle_prescriptions = prescriptions.select { |rx| rx.category.present? }
      expect(oracle_prescriptions).not_to be_empty
      
      # Verify all Oracle Health prescriptions have normalized VistA statuses
      oracle_prescriptions.each do |rx|
        expect(rx.refill_status).to be_in(%w[
          active expired discontinued refillinprocess 
          providerHold pending unknown
        ])
      end
    end
  end
  
  it 'leaves VistA prescription statuses unchanged' do
    VCR.use_cassette('uhd/get_prescriptions_vista') do
      prescriptions = subject.get_prescriptions
      
      vista_prescriptions = prescriptions.reject { |rx| rx.category.present? }
      expect(vista_prescriptions).not_to be_empty
      
      # Verify VistA prescriptions retain their original statuses
      vista_prescriptions.each do |rx|
        expect(rx.refill_status).to be_present
      end
    end
  end
end
```

### Request Tests: Mobile Controller

**File:** `modules/mobile/spec/requests/mobile/v1/prescriptions_spec.rb`

Verify mobile app compatibility:

```ruby
describe 'GET /mobile/v1/prescriptions with Oracle Health prescriptions' do
  before do
    allow(Flipper).to receive(:enabled?)
      .with(:mhv_medications_cerner_pilot, user)
      .and_return(true)
  end
  
  it 'returns Oracle Health prescriptions with VistA-compatible statuses' do
    VCR.use_cassette('mobile/prescriptions/mixed_vista_oracle_health') do
      get '/mobile/v1/prescriptions', headers: iam_headers
      
      expect(response).to have_http_status(:ok)
      
      prescriptions = JSON.parse(response.body)['data']
      
      # Verify status_meta counts work correctly with normalized statuses
      meta = JSON.parse(response.body)['meta']
      expect(meta['prescription_status_count']).to include('active', 'isRefillable')
    end
  end
  
  it 'properly categorizes refillinprocess prescriptions as active' do
    VCR.use_cassette('mobile/prescriptions/oracle_health_in_progress') do
      get '/mobile/v1/prescriptions', headers: iam_headers
      
      meta = JSON.parse(response.body)['meta']
      
      # refillinprocess should be counted as active per status_meta logic
      expect(meta['prescription_status_count']['active']).to be > 0
    end
  end
end
```

---

## Rollout Plan

### Phase 1: Development & Testing (Week 1)
- [ ] Implement adapter changes
- [ ] Add comprehensive unit tests
- [ ] Add integration tests
- [ ] Code review
- [ ] Merge to feature branch

### Phase 2: Staging Validation (Week 1)
- [ ] Deploy to staging
- [ ] Validate VistA prescriptions unchanged (critical verification)
- [ ] Validate Oracle Health prescriptions normalized correctly
- [ ] Test mobile app with mixed prescription lists
- [ ] Performance testing (verify no significant latency added)
- [ ] Verify status_meta counts accurate with normalized statuses

### Phase 3: Production Deployment (Week 2)
- [ ] Deploy to production
- [ ] Monitor logs for normalization events (first 24 hours)
- [ ] Monitor error rates and latency
- [ ] Validate mobile app analytics show correct behavior
- [ ] Monitor for 1 week minimum before declaring stable

---

## Monitoring & Observability

### Logging

Add structured logging for each normalization:

```ruby
Rails.logger.info(
  message: 'Oracle Health status normalized',
  prescription_id: resource['id'],
  original_status: mr_status,
  normalized_status: normalized_status,
  refills_remaining: refills_remaining,
  expiration_date: expiration_date,
  has_in_progress_dispense: has_in_progress_dispense,
  service: 'unified_health_data'
)
```

### StatsD Metrics

Track normalization frequency:

```ruby
StatsD.increment('unified_health_data.oracle_health.status_normalization', 
                 tags: ["original_status:#{mr_status}", "normalized_status:#{normalized_status}"])
```

### Datadog Tracing

Add span tags for observability:

```ruby
Datadog::Tracing.trace('uhd.oracle_health.status_normalization') do |span|
  span.set_tag('original_status', mr_status)
  span.set_tag('normalized_status', normalized_status)
  # ... normalization logic
end
```

---

## Risks & Mitigations

### Risk 1: Breaking Change for Other Consumers
**Impact:** Medium  
**Probability:** Low  
**Mitigation:**
- Comprehensive testing in staging before production
- VistA prescriptions completely unaffected (adapter only changes Oracle Health)
- Only Oracle Health prescriptions normalized
- Mobile app already handles all VistA status values

### Risk 2: Mobile App Incompatibility
**Impact:** High  
**Probability:** Low  
**Mitigation:**
- Mobile app already handles VistA statuses
- New statuses (`pending`, `unknown`) may need mobile app verification
- Test with actual mobile app in staging
- `pending` status may conflict with existing "PD" source filtering

### Risk 3: Incorrect Status Mapping
**Impact:** Medium  
**Probability:** Low  
**Mitigation:**
- Comprehensive unit test coverage (all 20+ scenarios)
- Validation with product team on mapping rules
- Detailed logging for monitoring transformations
- Can rollback deployment if issues found in production

### Risk 4: Date/Timezone Issues
**Impact:** Medium  
**Probability:** Medium  
**Mitigation:**
- Explicit UTC conversion and comparison
- Test with dates in different timezones
- Handle missing/invalid dates gracefully
- Log parsing failures

### Risk 5: Performance Impact
**Impact:** Low  
**Probability:** Low  
**Mitigation:**
- Normalization adds minimal processing (O(n) for dispense check)
- No additional API calls
- Performance testing in staging
- Monitor latency metrics in production

---

## Logging Strategy

### Verbosity During Rollout

**Initial deployment (first 2 weeks):**
- Log every normalization at INFO level for validation
- Includes: prescription_id, original_status, normalized_status, refills_remaining, has_in_progress_dispense
- Allows verification of mapping rules in production
- Helps identify edge cases not covered in testing

**After stable (2+ weeks):**
- Reduce to sampling (e.g., 10% of normalizations) or DEBUG level
- Continue logging unexpected statuses at WARN level
- Keep StatsD metrics for ongoing monitoring

### Log Monitoring

Monitor logs for:
- High frequency of unexpected statuses (WARN logs)
- Mismatches between expected and actual normalized statuses
- Any ERROR logs from date parsing or other failures

---

## Success Criteria

- [ ] All Oracle Health prescriptions return VistA-compatible status values
- [ ] VistA prescriptions completely unaffected (verified via tests)
- [ ] Mobile app displays Oracle Health prescriptions correctly without code changes
- [ ] `status_meta` counts are accurate for mixed prescription lists
- [ ] No increase in error rates or latency (< 5ms additional processing time)
- [ ] 100% test coverage for normalization logic
- [ ] Product team sign-off on status mappings
- [ ] Logs show expected normalization patterns in production

---

## References

- **Status Mapping CSV:** `docs/status_mapping.csv`
- **Current Adapter:** `lib/unified_health_data/adapters/oracle_health_prescription_adapter.rb`
- **Mobile Controller:** `modules/mobile/app/controllers/mobile/v1/prescriptions_controller.rb`
- **FHIR MedicationRequest:** https://hl7.org/fhir/R4/medicationrequest.html
- **FHIR MedicationDispense:** https://hl7.org/fhir/R4/medicationdispense.html

---

## Appendix: VistA Status Reference

Current VistA statuses found in codebase:

| Status | Description | Mobile App Usage |
|--------|-------------|------------------|
| `active` | Active prescription, refillable | Counted as "active" |
| `activeParked` | Active but temporarily on hold | Counted as "active" |
| `providerHold` | On hold by provider | Counted as "active" |
| `refillinprocess` | Refill being processed | Counted as "active" |
| `submitted` | Refill request submitted | Counted as "active" |
| `discontinued` | Discontinued by provider | Not counted as "active" |
| `expired` | Expired prescription | Not counted as "active" |

**Source:** `modules/mobile/app/controllers/mobile/v1/prescriptions_controller.rb:97-98`
