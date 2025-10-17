# Appointments API Latency Analysis

## Problem Statement
The average request latency for `mobile/v0/appointments#index` exhibited unusual patterns:
- Increased by ~0.75s around July 15th
- Decreased by over 1 second around August 10th  
- Increased again around September 4th

Meanwhile, `vaos/v2/appointments#index` remained consistent throughout this period. Both endpoints use the same backend service (`VAOS::V2::AppointmentsService`).

## Architecture Overview

### mobile/v0/appointments#index Flow:
1. `Mobile::V0::AppointmentsController#index`
2. → `Mobile::V2::Appointments::Proxy#get_appointments`
3. → `VAOS::V2::AppointmentsService#get_appointments`
4. → Applies presentation filter (conditionally based on `:appointments_consolidation` flipper)
5. → `Mobile::V0::Adapters::VAOSV2Appointments#parse` (converts VAOS V2 → Mobile V0 schema)
6. → Filters appointments (e.g., pending status)
7. → Sorts by `start_date_utc`
8. → `Mobile::PaginationHelper.paginate` (client-side pagination with array slicing)
9. → Calculates `upcoming_appointments_count`
10. → Calculates `travel_pay_eligible_count` (conditionally based on `include_claims?`)
11. → `Mobile::V0::AppointmentSerializer.new`

### vaos/v2/appointments#index Flow:
1. `VAOS::V2::AppointmentsController#index`
2. → `VAOS::V2::AppointmentsService#get_appointments`
3. → Applies presentation filter (conditionally based on `:appointments_consolidation` flipper)
4. → No adapter conversion (uses VAOS V2 schema directly)
5. → No additional sorting
6. → No client-side pagination (pagination params passed to backend but not fully utilized)
7. → No count calculations
8. → `VAOS::V2::VAOSSerializer.new`

## Key Differences

### 1. Data Transformation Layer (Mobile Only)
**Location:** `Mobile::V0::Adapters::VAOSV2Appointments#parse`
- Mobile endpoint must convert VAOS V2 schema to Mobile V0 schema for backward compatibility
- This involves iterating through all appointments and transforming each one via `VAOSV2Appointment#build_appointment_model`
- **Impact:** O(n) transformation overhead on every appointment

### 2. Client-Side Pagination (Mobile Only)
**Location:** `Mobile::PaginationHelper.paginate`
- Mobile uses `list.each_slice(page_size).to_a` which loads all appointments into memory and slices them
- VAOS passes pagination params to backend but doesn't perform client-side slicing
- **Impact:** Even if client requests page 1 with 10 items, mobile endpoint processes ALL appointments returned from backend

### 3. Additional Sorting (Mobile Only)
**Location:** `Mobile::V2::Appointments::Proxy#get_appointments` (line 38)
```ruby
[appointments.sort_by(&:start_date_utc), response[:meta][:failures]]
```
- Mobile explicitly sorts ALL appointments by `start_date_utc`
- VAOS relies on backend ordering
- **Impact:** O(n log n) sorting operation on complete result set

### 4. Count Calculations (Mobile Only)

**upcoming_appointments_count:**
```ruby
def upcoming_appointments_count(appointments)
  appointments.count do |appt|
    appt.is_pending == false && appt.status == 'BOOKED' && appt.start_date_utc > Time.now.utc &&
      appt.start_date_utc <= UPCOMING_DAYS_LIMIT.days.from_now.end_of_day.utc
  end
end
```
- Iterates through ALL appointments
- **Impact:** O(n) iteration with date comparisons

**travel_pay_eligible_count (conditional):**
```ruby
def travel_pay_eligible_count(appointments)
  appointments.count do |appt|
    appt.travel_pay_eligible == true &&
      appt.start_date_utc >= TRAVEL_PAY_DAYS_LIMIT.days.ago.utc &&
      appt[:travelPayClaim][:claim].nil?
  end
end
```
- Only runs when `include_claims?` is true
- Iterates through ALL appointments
- Accesses nested hash `appt[:travelPayClaim][:claim]`
- **Impact:** O(n) iteration with nested hash access

### 5. Presentation Filter Behavior
**Location:** `VAOS::V2::AppointmentsPresentationFilter#user_facing?`

Both endpoints apply this filter when `:appointments_consolidation` flipper is enabled, but:
- Mobile applies it in `Mobile::V2::Appointments::Proxy` (line 31-34)
- VAOS applies it in `VAOS::V2::AppointmentsService` (line 74-91)

**Key difference:** The filter is conditionally applied based on the `:appointments_consolidation` feature flag per user. If this flag was toggled around the dates in question, it could affect both endpoints, but mobile has additional processing regardless.

## Theories on Latency Pattern

### Theory 1: Travel Pay Claims Feature Toggle (~40% probability)
**Hypothesis:** The `include_claims` parameter was enabled around July 15th and September 4th, disabled around August 10th.

**Evidence:**

**CRITICAL: External Travel Pay API Call**
When `include[:travel_pay_claims]` is true AND `:travel_pay_view_claim_details` flipper is enabled, BOTH endpoints call:
```ruby
TravelPay::ClaimAssociationService#associate_appointments_to_claims
```

This service:
1. Makes an external HTTP call to `client.get_claims_by_date(veis_token, btsss_token, client_params)`
2. Requires VEIS and BTSSS token authorization
3. Iterates through all claims to match with appointments by date/time
4. This is a synchronous blocking operation

**However**, if the external API affects both endpoints equally, why the difference?

**Mobile-Specific Additional Work:**
After the shared travel pay merging, Mobile additionally:
1. Calculates `travel_pay_eligible_count` - O(n) iteration checking:
   - `appt.travel_pay_eligible == true`
   - `appt.start_date_utc >= TRAVEL_PAY_DAYS_LIMIT.days.ago.utc`
   - `appt[:travelPayClaim][:claim].nil?` (nested hash access)

2. This count is calculated on ALL appointments in the dataset, not just the paginated subset
3. The nested hash access `appt[:travelPayClaim][:claim]` can be expensive if structure is complex

**Why VAOS less affected:**
- VAOS calls the same external API BUT doesn't do the additional counting iteration
- VAOS might have fewer appointments due to pagination params being respected differently
- If external API is slow, both would be slow, but mobile adds the O(n) count on top

**Refined Theory:**
- External travel pay API may have been slow/enabled during high latency periods
- Mobile's additional `travel_pay_eligible_count` iteration compounds the problem
- Combined effect: External API latency + O(n) counting = significant delay for mobile only

**Expected latency impact:** 
- External API: 0.3-0.8s (affects both equally)
- Mobile counting: 0.2-0.5s (mobile only)
- Total mobile impact: 0.5-1.3s

### Theory 2: Appointments Consolidation Filter Toggle (~30% probability)
**Hypothesis:** The `:appointments_consolidation` feature flag was toggled for mobile users around these dates, affecting which appointments are included in the response.

**Evidence:**
- Mobile proxy applies `AppointmentsPresentationFilter` only when flag is DISABLED (line 31-33):
  ```ruby
  unless Flipper.enabled?(:appointments_consolidation, @user)
    filterer = VAOS::V2::AppointmentsPresentationFilter.new
    appointments.keep_if { |appt| filterer.user_facing?(appt) }
  end
  ```
- VAOS applies the filter when flag is ENABLED (line 74-91)
- **INVERTED LOGIC** between the two endpoints!

**Behavior Analysis:**

When `:appointments_consolidation` is **DISABLED**:
- Mobile: Applies filter → Removes non-user-facing appointments → SMALLER dataset
- VAOS: Skips filter → Includes all appointments → LARGER dataset

When `:appointments_consolidation` is **ENABLED**:
- Mobile: Skips filter → Includes all appointments → LARGER dataset  
- VAOS: Applies filter → Removes non-user-facing appointments → SMALLER dataset

**Why this explains the pattern:**
- July 15th: Flag enabled → Mobile processes MORE appointments → Slower
- August 10th: Flag disabled → Mobile processes FEWER appointments → Faster
- September 4th: Flag enabled again → Mobile processes MORE appointments → Slower

**Why VAOS unaffected:**
- VAOS doesn't do expensive per-appointment operations (no adapter, no counts, no sorting)
- Even with more appointments, VAOS impact is minimal
- The filter in VAOS is primarily for EPS appointment consolidation, not performance

**Expected latency impact:** Depends on filter effectiveness. If filter removes 30-40% of appointments, and mobile has O(n) operations, this could easily account for 0.5-1.0s difference.

### Theory 3: Data Volume Changes from Backend (~20% probability)
**Hypothesis:** The backend service (VAOS/VPG) returned significantly more appointments during the high-latency periods.

**Evidence:**
- All mobile-specific operations are O(n): adapter parsing, sorting, pagination slicing, count calculations
- If backend returned 3x more appointments, mobile would do 3x more work
- VAOS does minimal processing per appointment (no adapter, no counts)
- Could be related to EPS appointments being included/excluded

**Why VAOS less affected:**
- VAOS has much less per-appointment processing
- Linear growth in mobile would appear as step change, while VAOS sees smaller impact

**Expected latency impact:** Proportional to appointment count increase (2-3x data → 2-3x latency)

### Theory 4: Adapter/Serialization Changes (~10% probability)  
**Hypothesis:** Changes to `VAOSV2Appointment#build_appointment_model` or related serialization code around these dates.

**Evidence:**
- The adapter is only used by mobile endpoint
- Each appointment must be transformed from VAOS V2 to Mobile V0 schema
- Complex transformations could have been added/modified

**Limitations:**
- Would need git history analysis to confirm code changes
- Couldn't find obvious commits in initial git log search
- This seems less likely given the pattern reverses (suggests toggle rather than persistent change)

**Expected latency impact:** 0.1-0.3s per appointment depending on transformation complexity

## Recommendations for Investigation

1. **Check Flipper audit logs** for these feature flags around the dates:
   - `:appointments_consolidation`
   - `:travel_pay_view_claim_details`
   - Any mobile-specific flags affecting the `include` parameter

2. **Query application logs** for:
   - Average appointment counts returned during these periods
   - Frequency of `include_claims=true` requests
   - Presence of EPS appointments in responses

3. **Review StatsD/DataDog metrics** for:
   - Response sizes (body size in bytes)
   - Appointment counts in responses
   - Travel pay claim feature usage

4. **Analyze git history** around dates more thoroughly:
   ```bash
   git log --since="2024-07-10" --until="2024-07-20" --all --oneline
   git log --since="2024-08-05" --until="2024-08-15" --all --oneline  
   git log --since="2024-09-01" --until="2024-09-08" --all --oneline
   ```

## Performance Optimization Opportunities (Future Work)

1. **Eliminate adapter layer:** Migrate mobile clients to VAOS V2 schema
2. **Backend pagination:** Use proper pagination to limit dataset size
3. **Lazy count calculation:** Only calculate counts when specifically requested
4. **Caching:** Cache expensive calculations like travel pay eligibility
5. **Indexed queries:** Pre-calculate counts on backend rather than iterating full dataset

## Summary

Based on the code analysis, here are the 4 most likely theories explaining the latency pattern, ordered by probability:

### Theory 1: Travel Pay Claims Feature (40% probability)
**Cause:** The `include_claims` parameter or `:travel_pay_view_claim_details` flipper was toggled on during high-latency periods.

**Impact:** 
- External Travel Pay API call (affects both endpoints): +0.3-0.8s
- Mobile-only `travel_pay_eligible_count` iteration: +0.2-0.5s  
- **Total mobile impact: +0.5-1.3s**
- VAOS impact: +0.3-0.8s (much less noticeable)

**Supporting Evidence:**
- External HTTP call to travel pay service with auth tokens
- Mobile performs additional O(n) count with nested hash access
- Explains why VAOS remained "consistent" (smaller impact)

### Theory 2: Appointments Consolidation Filter (30% probability)
**Cause:** The `:appointments_consolidation` flipper was toggled, affecting dataset sizes due to inverted logic between endpoints.

**Pattern:**
- Flag ENABLED → Mobile has LARGER dataset → SLOWER
- Flag DISABLED → Mobile has SMALLER dataset → FASTER

**Impact:**
- If filter removes 30-40% appointments: +0.5-1.0s for mobile
- Mobile's O(n) operations (adapter, sort, counts) amplify the dataset increase
- VAOS does minimal per-appointment work, so less affected

**Supporting Evidence:**
- Inverted `unless Flipper.enabled?` logic in mobile proxy
- Multiple expensive O(n) operations scale with dataset size
- Matches pattern: up, down, up again

### Theory 3: Backend Data Volume Changes (20% probability)  
**Cause:** The VAOS/VPG backend returned significantly more appointments during high-latency periods (e.g., EPS appointments included/excluded).

**Impact:**
- 2-3x data increase → 2-3x latency for mobile's O(n) operations
- Mobile: adapter parsing, sorting, pagination, counts all scale linearly
- VAOS: minimal per-appointment processing, sees smaller impact

**Limitations:**
- Doesn't explain why VAOS remained perfectly stable
- Would need to explain why backend volume changed on specific dates
- Less likely unless tied to a configuration change

### Theory 4: Adapter/Serialization Code Changes (10% probability)
**Cause:** Changes to `VAOSV2Appointment#build_appointment_model` or serialization logic introduced performance regression.

**Impact:**
- Could add 0.1-0.3s per appointment transformation
- Only affects mobile endpoint (VAOS doesn't use adapter)

**Limitations:**
- Pattern reverses (up → down → up), suggesting toggle not persistent change
- No obvious commits found in initial git history search
- Less likely but worth checking git history thoroughly

## Recommended Investigation Steps

1. **Flipper Audit Logs** (High Priority):
   - Check `:travel_pay_view_claim_details` flag status on: July 15, Aug 10, Sept 4
   - Check `:appointments_consolidation` flag status for same dates
   - Look for any mobile-specific flag changes

2. **Application Logs Analysis**:
   - Query for `include_claims=true` frequency around those dates
   - Check average appointment counts in responses
   - Look for travel pay API errors or timeouts

3. **External Service Monitoring**:
   - Travel Pay API response times during those periods
   - VEIS/BTSSS token authorization latency
   - Any known travel pay service incidents

4. **Metrics/DataDog**:
   - Response payload sizes (bytes) over time
   - Appointment count distribution in responses
   - Mobile vs VAOS request patterns (parameter usage)

5. **Git History Deep Dive**:
   ```bash
   # Check all changes to key files around those dates
   git log -p --since="2024-07-10" --until="2024-09-10" \
     -- modules/mobile/app/models/mobile/v0/adapters/vaos_v2_appointment.rb
   ```

## Conclusion

The most probable cause (40% confidence) is **Theory 1: Travel Pay Claims Feature Toggle**. The combination of:
1. External travel pay API calls (affects both, but noticeable in VAOS as smaller delay)
2. Mobile-specific counting iteration with nested hash access (compounds the problem)

This best explains why mobile saw significant latency changes while VAOS remained "consistent" - VAOS was affected but by a smaller margin that didn't stand out in metrics.

The second most likely (30% confidence) is **Theory 2: Appointments Consolidation Filter** due to the inverted logic and mobile's multiple O(n) operations that amplify dataset size changes.

Both theories involve feature flags that can be toggled independently, matching the pattern of changes occurring on specific dates and reversing rather than persisting.
