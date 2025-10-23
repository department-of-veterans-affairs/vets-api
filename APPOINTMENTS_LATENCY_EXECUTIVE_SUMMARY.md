# Appointments Latency Analysis - Executive Summary

## Problem
Mobile appointments endpoint (`mobile/v0/appointments#index`) experienced latency spikes (~0.75-1.0s) on specific dates (July 15, Aug 10, Sept 4) while VAOS v2 endpoint remained stable. Both use the same backend service.

## Root Cause Theories

### 🏆 Most Likely (40%): Travel Pay Claims Feature Toggle
- **What:** Feature flag enabling external Travel Pay API integration
- **Why Mobile Affected:** Mobile makes the same external API call PLUS does additional O(n) counting iteration
- **Impact:** +0.5-1.3s for mobile, +0.3-0.8s for VAOS (less noticeable)
- **Pattern:** Toggled ON → slow, OFF → fast, ON → slow

### 🥈 Second (30%): Appointments Consolidation Filter
- **What:** Feature flag with inverted logic between mobile and VAOS
- **Why Different:** Mobile applies filter when flag OFF, VAOS when flag ON
- **Impact:** 30-40% more appointments when flag is ON for mobile → slower due to O(n) operations
- **Pattern:** ON → more data → slower, OFF → less data → faster

### 🥉 Third (20%): Backend Data Volume Spike
- **What:** Backend returned more appointments (e.g., EPS appointments added)
- **Why Mobile Affected:** Mobile's 4-5 O(n) operations scale with data size
- **Impact:** Linear scaling with data volume

### Fourth (10%): Code Changes to Adapter
- **What:** Performance regression in schema conversion code
- **Why Mobile Only:** VAOS doesn't use the adapter layer
- **Limitation:** Pattern reverses, suggesting toggle not code change

## Why Mobile Is Vulnerable

Mobile endpoint performs **5 expensive operations** VAOS doesn't:

1. **Schema Adapter:** VAOS V2 → Mobile V0 conversion (O(n))
2. **Client-Side Pagination:** Processes ALL appointments even for page 1 (O(n))
3. **Sorting:** `sort_by(&:start_date_utc)` on entire dataset (O(n log n))
4. **Upcoming Count:** Count appointments in next 30 days (O(n))
5. **Travel Pay Count:** Count eligible appointments with nested hash access (O(n))

**Multiplier Effect:** A 2x increase in appointments → 2x work in each operation → significant latency

## Immediate Actions

1. **Check Flipper Audit Logs** (30 min):
   - `:travel_pay_view_claim_details` on July 15, Aug 10, Sept 4
   - `:appointments_consolidation` on same dates
   - Correlate with latency spikes

2. **Query Application Logs** (1 hour):
   - Count of `include_claims=true` requests
   - Average appointment counts in responses
   - Travel Pay API response times/errors

3. **Review Monitoring Dashboards** (30 min):
   - Response payload sizes over time
   - External Travel Pay API latency
   - Mobile vs VAOS request patterns

## Long-Term Recommendations

### Quick Wins (1-2 sprints)
1. **Lazy Count Calculation:** Only calculate counts when client explicitly requests them via parameter
2. **Backend Pagination:** Respect pagination params to limit dataset size (avoid processing 200 appointments to return 10)
3. **Cache Travel Pay Data:** Cache external API results with short TTL (5-10 min)

### Strategic (3-6 months)
1. **Migrate to VAOS V2 Schema:** Eliminate adapter layer overhead
2. **Backend Count Calculation:** Move expensive counts to backend service
3. **Streaming Responses:** Return paginated results without loading full dataset

### Performance Impact Estimates
- Lazy counts: -0.2-0.4s
- Backend pagination: -0.3-0.6s
- Remove adapter: -0.2-0.5s
- **Total potential improvement: 0.7-1.5s**

## Verification Plan

After identifying root cause, verify by:
1. Toggle identified flag in staging
2. Measure latency change
3. Confirm pattern matches production timeline
4. Document for post-mortem

## Key Contacts
- Mobile API Team: Feature flag decisions
- VAOS Team: Backend service owners
- Travel Pay Team: External API performance
- Platform Team: Flipper audit access

---

**Full Analysis:** See `APPOINTMENTS_LATENCY_ANALYSIS.md` for detailed code analysis, architecture diagrams, and investigation steps.
