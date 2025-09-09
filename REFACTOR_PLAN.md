# Mobile V1 Prescriptions Refactor Plan

## Overview
Move prescription transformation logic from mobile controller to UHD service level, creating a cleaner separation of concerns.

## Branch Strategy

### Current State
- `main` branch at commit `4b68d6b198a78f03fb0b27814a3e3bde04519a31`
- `feature/mobile_v1_prescriptions_uhd` contains all our current work

### Target Branches

#### Branch 1: `feature/uhd-prescription-transformation`
- **Base**: `4b68d6b198a78f03fb0b27814a3e3bde04519a31` (main)
- **Purpose**: Add transformation logic to UHD service
- **Scope**: 
  - Create/enhance UHD service to handle Vista + Oracle Health prescription data
  - Transform raw external service data into mobile-ready format
  - Handle tracking info arrays, field mapping, data normalization
  - No mobile-specific code, just clean data transformation

#### Branch 2: `feature/mobile-v1-prescriptions-clean`
- **Base**: Tip of Branch 1
- **Purpose**: Clean mobile v1 controller implementation
- **Scope**:
  - Simple mobile v1 controller that consumes transformed UHD data
  - Mobile-specific metadata (prescriptionStatusCount, hasNonVaMeds)
  - Mobile v1 serializer (inherits from v0, adds UHD fields)
  - Pagination, feature flags, error handling
  - No transformation logic (handled by UHD service)

## Implementation Progress

### Phase 1: Setup Branches
- [x] Create Branch 1 from `4b68d6b198a78f03fb0b27814a3e3bde04519a31`
- [x] Implement UHD service transformation logic
- [x] Test UHD service independently
- [ ] Merge Branch 1 to main

### Phase 2: Mobile Implementation
- [ ] Create Branch 2 from tip of Branch 1
- [ ] Port mobile controller logic (minus transformation)
- [ ] Update mobile controller to use enhanced UHD service
- [ ] Test complete flow
- [ ] Merge Branch 2 to main

## Detailed Implementation Plan

### Branch 1: UHD Service Enhancement

#### Files to Create/Modify:
- [x] `lib/unified_health_data/models/prescription_attributes.rb` - Added tracking_info, prescription_source, ndc_number, prescribed_date
- [x] `lib/unified_health_data/models/prescription.rb` - Added methods for mobile v1 compatibility
- [x] `lib/unified_health_data/adapters/vista_prescription_adapter.rb` - Enhanced with tracking info and new fields
- [x] `lib/unified_health_data/adapters/oracle_health_prescription_adapter.rb` - Enhanced with tracking info extraction
- [x] `spec/lib/unified_health_data/` - Comprehensive UHD service tests

#### UHD Service Responsibilities:
- [ ] Fetch Vista + Oracle Health prescription data from external APIs
- [ ] Transform raw data into consistent format
- [ ] Handle tracking info arrays (single → array, multiple tracking numbers)
- [ ] Normalize field names (fillDate → refill_date, etc.)
- [ ] Handle boolean conversions (refillable?, trackable?)
- [ ] Return structured prescription objects ready for mobile consumption

#### UHD Service Interface:
```ruby
class UnifiedHealthData::Service
  def get_prescriptions(user_icn, **options)
    # Returns array of UnifiedHealthData::Models::Prescription objects
    # Each prescription includes:
    # - All mobile v0 compatible fields
    # - tracking_info array
    # - UHD-specific fields (data_source_system, prescription_source)
  end
end
```

### Branch 2: Clean Mobile Implementation

#### Files to Create/Modify:
- [ ] `modules/mobile/app/controllers/mobile/v1/prescriptions_controller.rb`
- [ ] `modules/mobile/app/serializers/mobile/v1/prescriptions_serializer.rb`
- [ ] `modules/mobile/config/routes.rb`
- [ ] `modules/mobile/spec/requests/mobile/v1/health/prescriptions_spec.rb`

#### Mobile Controller Responsibilities:
- [ ] Authentication and authorization
- [ ] Feature flag validation
- [ ] Call UHD service with user ICN
- [ ] Generate mobile-specific metadata (prescriptionStatusCount, hasNonVaMeds)
- [ ] Pagination
- [ ] Error handling and logging (without PII)
- [ ] Response serialization

#### Simplified Mobile Controller:
```ruby
class Mobile::V1::PrescriptionsController < ApplicationController
  def index
    # 1. Validate feature flag
    # 2. Get transformed prescriptions from UHD service
    # 3. Generate mobile metadata
    # 4. Paginate and serialize
  end
end
```

## Testing Strategy

### Branch 1 Tests:
- [ ] UHD service unit tests (external API mocking)
- [ ] Transformation logic tests (Vista/Oracle Health data → mobile format)
- [ ] Tracking info array handling tests
- [ ] Field mapping and normalization tests
- [ ] Error handling tests

### Branch 2 Tests:
- [ ] Mobile controller integration tests
- [ ] Metadata generation tests  
- [ ] Pagination tests
- [ ] Feature flag tests
- [ ] Serializer tests (v0 compatibility + v1 extensions)

## Migration Benefits

### Code Organization:
- ✅ UHD service focused on data transformation
- ✅ Mobile controller focused on mobile-specific concerns
- ✅ Clear separation of responsibilities
- ✅ Easier testing and maintenance

### Reusability:
- ✅ UHD service can be used by other VA.gov services
- ✅ Transformation logic centralized and consistent
- ✅ Mobile controller becomes simpler and more maintainable

## Merge Strategy

1. **Branch 1 → Main**: UHD service enhancement
2. **Branch 2 → Main**: Clean mobile implementation
3. **Cleanup**: Remove old `feature/mobile_v1_prescriptions_uhd` branch

## Rollback Plan
- Keep existing mobile v0 endpoint unchanged
- Feature flag controls v1 endpoint availability
- Can quickly disable v1 if issues arise

---

This plan separates the complex data transformation concerns from mobile-specific logic, making the codebase more maintainable and the UHD service reusable across VA.gov.
