# UHD Pre-Cache at Sign-In - Architecture & Implementation Plan

## Executive Summary

This document outlines the architecture and implementation plan for asynchronously pre-caching Unified Health Data (UHD) resources when veterans sign in to VA.gov or the VA Health and Benefits mobile app. By fetching health data (labs, medications, vitals, conditions, allergies, clinical notes) at sign-in time, we can leverage the 20-minute TTL cache in the upstream SCDF service to provide near-instant data availability when users navigate to health pages.

**Status**: Architecture & Planning Phase (NOT YET IMPLEMENTED)  
**Target Feature Flag**: `mhv_accelerated_delivery_labs` (as per new requirement)  
**Upstream Cache**: SCDF has a 20-minute TTL cache for EHR data

---

## Problem Statement

When veterans navigate to health-related pages on VA.gov (e.g., `/my-health/medications`), the system must:
1. Call UHD service to fetch data
2. UHD calls SCDF (Streaming Cloud Data Flow)
3. SCDF queries EHR systems (VistA and Oracle Health/Cerner)
4. Data flows back through the chain to the user

This results in:
- **Initial page load latency** (multiple seconds to minutes)
- **Poor user experience** during first access
- **Inefficient cache utilization** (20-min SCDF cache not leveraged)

**Solution**: Pre-fetch and warm the SCDF cache at sign-in time, so when users navigate to health pages, data is already cached and returns quickly.

---

## Goals & Non-Goals

### Goals
1. **Reduce perceived latency** for health data pages by pre-warming SCDF cache
2. **Improve user experience** with near-instant data availability
3. **Leverage existing infrastructure** (Sidekiq, UHD service, SCDF cache)
4. **Enable gradual rollout** via feature flag (`mhv_accelerated_delivery_labs`)
5. **Maintain system stability** with proper error handling and monitoring

### Non-Goals
1. **NOT** caching data in vets-api (SCDF is the cache layer)
2. **NOT** modifying SCDF or EHR systems
3. **NOT** guaranteeing 100% cache hits (users may wait >20min before accessing health data)
4. **NOT** pre-caching for unauthenticated users

---

## Architecture Overview

### High-Level Flow

```
┌─────────────────┐
│  User Signs In  │
│   (VA.gov or    │
│   Mobile App)   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│  V0::SignInController       │
│  - token endpoint           │
│  - SessionCreator creates   │
│    OAuth session            │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  AfterLoginActions          │
│  (NEW - trigger job)        │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  Sidekiq Job Queue          │
│  UnifiedHealthData::        │
│  PrecacheJob.perform_async │
└────────┬────────────────────┘
         │
         ▼ (async execution)
┌─────────────────────────────┐
│  PrecacheJob                │
│  - Check feature flag       │
│  - Find user                │
│  - Call all UHD resources   │
└────────┬────────────────────┘
         │
         ▼ (parallel calls)
┌─────────────────────────────┐
│  UnifiedHealthData::Service │
│  - get_labs()               │
│  - get_prescriptions()      │
│  - get_vitals()             │
│  - get_conditions()         │
│  - get_allergies()          │
│  - get_care_summaries_and_  │
│    notes()                  │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  UnifiedHealthData::Client  │
│  - HTTP calls to UHD/SCDF   │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  SCDF Service               │
│  - Queries EHR systems      │
│  - Caches results (20min)   │
└─────────────────────────────┘
```

### Key Components

#### 1. **Trigger Point: After Sign-In Hook**
- **Location**: `app/services/login/after_login_actions.rb` or `app/services/sign_in/session_creator.rb`
- **Responsibility**: Enqueue async job after successful authentication
- **Feature Flag Check**: `Flipper.enabled?(:mhv_accelerated_delivery_labs, user)`

#### 2. **Sidekiq Job: UnifiedHealthData::PrecacheJob**
- **Location**: `app/sidekiq/unified_health_data/precache_job.rb`
- **Responsibility**: 
  - Validate user exists and has necessary permissions
  - Check feature flag
  - Call all UHD resource endpoints
  - Handle errors gracefully (no impact on sign-in flow)
  - Log success/failure metrics

#### 3. **Service Layer: UnifiedHealthData::Service** (existing)
- **Location**: `lib/unified_health_data/service.rb`
- **Responsibility**: Already has methods for all resources
  - `get_labs(start_date:, end_date:)`
  - `get_prescriptions(current_only:)`
  - `get_vitals()`
  - `get_conditions()`
  - `get_allergies()`
  - `get_care_summaries_and_notes(start_date:, end_date:)`

#### 4. **Client Layer: UnifiedHealthData::Client** (existing)
- **Location**: `lib/unified_health_data/client.rb`
- **Responsibility**: HTTP communication with UHD/SCDF

---

## Technical Design Decisions

### 1. Where to Trigger the Job

**Option A: In `Login::AfterLoginActions`** ✅ RECOMMENDED
- **Pros**:
  - Centralized post-login logic
  - Already handles MHV account creation async
  - Clean separation of concerns
  - Easy to test
- **Cons**:
  - Adds to existing service

**Option B: In `SignIn::SessionCreator`**
- **Pros**:
  - Closer to session creation
- **Cons**:
  - More coupling with core auth logic
  - Less maintainable

**Option C: In `SignIn::TokenResponseGenerator`**
- **Pros**:
  - Multiple grant types handled
- **Cons**:
  - Fires on token refresh (not just sign-in)
  - Would need filtering logic

**DECISION**: Use Option A (`Login::AfterLoginActions`) for cleaner integration.

---

### 2. Job Configuration

\`\`\`ruby
class UnifiedHealthData::PrecacheJob
  include Sidekiq::Job
  
  # Configuration decisions:
  sidekiq_options retry: 2, unique_for: 5.minutes
  
  # retry: 2 - Limited retries (if SCDF is down, no point hammering)
  # unique_for: 5.minutes - Prevent duplicate jobs if user signs in repeatedly
end
\`\`\`

**Rationale**:
- **Low retry count**: If SCDF/UHD is unavailable, retrying won't help and wastes resources
- **Uniqueness window**: Prevent job queue flooding if user refreshes/re-authenticates
- **No queue priority**: Run in default queue (not critical path)

---

### 3. Resource Fetching Strategy

**Option A: Sequential Fetches** 
\`\`\`ruby
get_labs
get_prescriptions
get_vitals
# ... etc
\`\`\`
- **Pros**: Simple, easier to debug
- **Cons**: Slower (6+ seconds total)

**Option B: Parallel Fetches** ✅ RECOMMENDED
\`\`\`ruby
futures = [
  Concurrent::Future.execute { get_labs },
  Concurrent::Future.execute { get_prescriptions },
  # ...
]
futures.each(&:wait)
\`\`\`
- **Pros**: Faster (1-2 seconds total), better cache warming
- **Cons**: More complex, harder to debug

**Option C: Separate Jobs per Resource**
\`\`\`ruby
LabsPrecacheJob.perform_async(user_uuid)
PrescriptionsPrecacheJob.perform_async(user_uuid)
# ...
\`\`\`
- **Pros**: Granular control, independent retries
- **Cons**: 6x jobs per sign-in, harder to coordinate

**DECISION**: Use Option B (parallel fetches) for performance, with fallback error handling per resource.

---

### 4. Date Range for Queries

Most UHD service methods require `start_date` and `end_date`:

**Option A: Use Service Defaults** ✅ RECOMMENDED
\`\`\`ruby
# Service already defines:
# default_start_date = '1900-01-01'
# default_end_date = Time.zone.today.to_s
\`\`\`
- **Pros**: Consistent with existing usage, comprehensive data
- **Cons**: May fetch more data than needed

**Option B: Recent Data Only (e.g., last 2 years)**
\`\`\`ruby
start_date = (Date.current - 2.years).to_s
end_date = Date.current.to_s
\`\`\`
- **Pros**: Smaller payload, faster
- **Cons**: May miss older records users want to see

**DECISION**: Use Option A (service defaults) to ensure comprehensive cache warming.

---

### 5. Error Handling Strategy

Since this job runs **asynchronously** after sign-in is complete:
- **Failures MUST NOT impact sign-in success**
- **Failures should be logged and monitored**
- **Partial failures are acceptable** (some resources may succeed)

\`\`\`ruby
def perform(user_uuid)
  user = User.find(user_uuid)
  return unless user && enabled_for_user?(user)
  
  resources_to_fetch.each do |resource_name, fetch_method|
    begin
      fetch_method.call
      log_success(resource_name)
    rescue => e
      log_error(resource_name, e)
      # Continue to next resource (don't re-raise)
    end
  end
end
\`\`\`

---

### 6. Feature Flag Gating

**New Requirement**: Job should be conditioned on `mhv_accelerated_delivery_labs` toggle.

\`\`\`ruby
def enabled_for_user?(user)
  Flipper.enabled?(:mhv_accelerated_delivery_labs, user)
end
\`\`\`

**Rollout Strategy**:
1. **Phase 1**: 0% - Code deployed but disabled
2. **Phase 2**: 1% - Enable for 1% of users, monitor metrics
3. **Phase 3**: 5% - Expand to 5%, validate cache hit rates
4. **Phase 4**: 25% - Quarter rollout
5. **Phase 5**: 50% - Half rollout
6. **Phase 6**: 100% - Full rollout

---

## Implementation Plan

### Phase 1: Core Job Implementation

**Files to Create**:
1. `app/sidekiq/unified_health_data/precache_job.rb`
   - Feature flag check
   - User validation
   - Parallel resource fetching
   - Error handling per resource
   - Logging and metrics

**Files to Modify**:
1. `app/services/login/after_login_actions.rb`
   - Add job trigger: `UnifiedHealthData::PrecacheJob.perform_async(current_user.uuid)`

**Testing**:
1. `spec/sidekiq/unified_health_data/precache_job_spec.rb`
   - Test feature flag gating
   - Test user not found scenario
   - Test successful resource fetching
   - Test partial failure handling
   - Test metrics/logging
2. `spec/services/login/after_login_actions_spec.rb`
   - Test job enqueued on sign-in

---

### Phase 2: Monitoring & Observability

**Metrics to Track**:
1. **Job Execution**:
   - `unified_health_data.precache_job.enqueued` (counter)
   - `unified_health_data.precache_job.started` (counter)
   - `unified_health_data.precache_job.completed` (counter)
   - `unified_health_data.precache_job.failed` (counter)
   - `unified_health_data.precache_job.duration` (timer)

2. **Resource Fetching**:
   - `unified_health_data.precache_job.resource.success{resource=labs}` (counter)
   - `unified_health_data.precache_job.resource.error{resource=labs}` (counter)
   - `unified_health_data.precache_job.resource.duration{resource=labs}` (timer)

3. **User Impact**:
   - `unified_health_data.precache_job.users_enabled` (gauge)

**Logs to Add**:
\`\`\`ruby
Rails.logger.info(
  'UHD Precache Job started',
  user_uuid: user_uuid,
  feature_enabled: enabled
)

Rails.logger.info(
  'UHD Precache Job completed',
  user_uuid: user_uuid,
  resources_succeeded: succeeded_count,
  resources_failed: failed_count,
  duration_ms: elapsed_time
)

Rails.logger.error(
  'UHD Precache Job resource failed',
  user_uuid: user_uuid,
  resource: resource_name,
  error: error.message
)
\`\`\`

---

### Phase 3: Gradual Rollout

**Week 1**: Deploy to staging
- Enable for test users
- Validate metrics pipeline
- Check Sidekiq queue depth

**Week 2**: Production canary (1%)
- Enable for 1% via `mhv_accelerated_delivery_labs` actor flag
- Monitor:
  - Job success rate
  - UHD/SCDF error rates
  - Sidekiq queue latency
  - User-reported issues

**Week 3-4**: Incremental rollout (5% → 25% → 50%)
- Monitor cache hit improvements
- Track page load time improvements for `/my-health/*` pages
- Validate no performance degradation

**Week 5**: Full rollout (100%)
- Enable globally
- Document findings
- Update runbooks

---

## Testing Strategy

### Unit Tests
1. **PrecacheJob**:
   - Feature flag disabled → job returns early
   - User not found → job returns early
   - Successful resource fetch → logs success metric
   - Failed resource fetch → logs error, continues to next
   - Parallel execution → all resources attempted

2. **AfterLoginActions**:
   - Job enqueued after sign-in
   - Job NOT enqueued if user nil

### Integration Tests
1. **End-to-end sign-in flow**:
   - Sign in → verify job enqueued
   - Job executes → verify UHD service called
   - Verify no impact on sign-in response time

### Performance Tests
1. **Load testing**:
   - 100 concurrent sign-ins → verify Sidekiq handles queue
   - Monitor UHD/SCDF response times
   - Verify no cascade failures

---

## Monitoring & Alerting

### Dashboards to Create
1. **UHD Precache Job Health**:
   - Job enqueue rate
   - Job success/failure rates
   - Average execution time
   - Resource-specific success rates

2. **User Experience Impact**:
   - Page load times for `/my-health/*` (before vs after)
   - Cache hit rates (inferred from UHD response times)

### Alerts to Configure
1. **Job Failure Rate > 10%**:
   - Severity: Warning
   - Action: Investigate UHD/SCDF health

2. **Job Failure Rate > 50%**:
   - Severity: Critical
   - Action: Consider disabling feature flag

3. **Sidekiq Queue Depth > 10,000**:
   - Severity: Warning
   - Action: Check for job queue backup

---

## Risks & Mitigations

### Risk 1: UHD/SCDF Overload
**Description**: Mass sign-ins could flood UHD/SCDF with requests.

**Mitigation**:
- Gradual rollout via feature flag
- Monitor UHD/SCDF error rates during rollout
- Circuit breaker pattern (if errors spike, auto-disable)

### Risk 2: Sidekiq Queue Backup
**Description**: Jobs could overwhelm Sidekiq workers.

**Mitigation**:
- Use `unique_for: 5.minutes` to prevent duplicates
- Monitor queue depth
- Dedicated worker pool (optional, if needed)

### Risk 3: User Navigates Before Cache Warmed
**Description**: If user navigates to health page immediately after sign-in, cache may not be ready.

**Mitigation**:
- This is acceptable - user sees normal load time
- Most users don't navigate immediately
- 20-min cache window still benefits users who navigate later

### Risk 4: Stale Data
**Description**: User sees 20-minute-old data.

**Mitigation**:
- This is existing SCDF behavior (not new)
- Users can always manually refresh
- Benefits outweigh staleness concerns

### Risk 5: PII Logging
**Description**: Accidentally logging sensitive health data.

**Mitigation**:
- Log only metadata (user_uuid, resource names, counts)
- Never log actual health data
- Code review focus on PII

---

## Success Metrics

### Primary KPIs
1. **Cache Hit Rate**: % of health page loads served from SCDF cache
2. **Page Load Time**: Reduction in median load time for `/my-health/*` pages
3. **Job Success Rate**: % of precache jobs completing successfully

### Target Metrics (after 100% rollout)
- **Cache Hit Rate**: >70% (users navigating within 20min)
- **Page Load Time**: 50% reduction for cache hits
- **Job Success Rate**: >95%

---

## Future Enhancements

### Phase 2: Resource Prioritization
- Fetch medications and vitals first (most common)
- Defer less common resources (clinical notes)

### Phase 3: Intelligent Scheduling
- Track user behavior: which resources they access most
- Pre-fetch only frequently accessed resources

### Phase 4: Cache Duration Optimization
- Work with SCDF team to extend cache TTL if beneficial

### Phase 5: Mobile App Integration
- Ensure mobile sign-in also triggers pre-cache

---

## Open Questions

1. **Q**: Should we differentiate between web and mobile app sign-ins?
   - **A**: Yes, to start only implement for web sign-ins. Mobile has a different prefetch pattern.

2. **Q**: What if user signs in but has no health data?
   - **A**: UHD will return empty results; job logs success with 0 records.

3. **Q**: Should we pre-cache for users without MHV accounts?
   - **A**: Check for `user.va_patient?`; skip if not eligible.

4. **Q**: What about users in multiple facilities (VistA + Oracle Health)?
   - **A**: UHD service already handles this; job remains agnostic.

---

## References

- **Existing UHD Service**: `lib/unified_health_data/service.rb`
- **Existing UHD Client**: `lib/unified_health_data/client.rb`
- **Existing Labs Refresh Job**: `app/sidekiq/unified_health_data/labs_refresh_job.rb`
- **Sign-In Flow**: `app/services/login/after_login_actions.rb`
- **Feature Flags**: `config/features.yml`
- **Sidekiq Patterns**: `app/sidekiq/` (various examples)

---

## Conclusion

This plan provides a comprehensive approach to implementing asynchronous UHD data pre-caching at sign-in. The architecture leverages existing infrastructure (Sidekiq, UHD service, SCDF cache) while maintaining system stability through proper error handling, feature flagging, and gradual rollout.

**Key Benefits**:
- Improved user experience with faster health page loads
- Efficient use of SCDF's 20-minute cache
- Minimal risk due to async nature and gradual rollout
- Strong observability for monitoring impact

**Next Steps**:
1. Review and approve architecture
2. Implement Phase 1 (core job + integration)
3. Deploy to staging for testing
4. Begin gradual production rollout

---

**Document Status**: Draft for Review  
**Author**: GitHub Copilot  
**Date**: 2024-12-16  
**Version**: 1.0
