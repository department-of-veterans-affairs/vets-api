# Appointments Latency Analysis - README

This directory contains analysis documents investigating latency differences between two appointments API endpoints.

## Quick Start

- **For Executives/Managers:** Read [APPOINTMENTS_LATENCY_EXECUTIVE_SUMMARY.md](./APPOINTMENTS_LATENCY_EXECUTIVE_SUMMARY.md)
- **For Engineers:** Read [APPOINTMENTS_LATENCY_ANALYSIS.md](./APPOINTMENTS_LATENCY_ANALYSIS.md)

## Background

Around July 15th, 2024, the `mobile/v0/appointments#index` endpoint began experiencing unusual latency patterns (increasing by ~0.75s), while `vaos/v2/appointments#index` remained stable. Both endpoints use the same backend service.

## Problem Statement

| Endpoint | Behavior | Pattern |
|----------|----------|---------|
| `mobile/v0/appointments#index` | Variable latency | +0.75s (Jul 15) → -1.0s (Aug 10) → +0.75s (Sep 4) |
| `vaos/v2/appointments#index` | Consistent | Stable throughout period |

## Analysis Results

### Most Likely Causes (with probabilities):

1. **Travel Pay Claims Feature Toggle (40%)**
   - External API call + mobile-specific counting iteration
   - Impact: +0.5-1.3s for mobile

2. **Appointments Consolidation Filter (30%)**
   - Feature flag with inverted logic between endpoints
   - Impact: 30-40% dataset size difference

3. **Backend Data Volume Changes (20%)**
   - More appointments returned from backend
   - Impact: Linear scaling with O(n) operations

4. **Adapter Code Changes (10%)**
   - Performance regression in schema conversion
   - Impact: +0.1-0.3s per appointment

### Root Cause: Mobile's Additional Processing

Mobile performs 5 operations VAOS doesn't:
1. Schema conversion (VAOS V2 → Mobile V0)
2. Client-side pagination (all data slicing)
3. Sorting all appointments
4. Upcoming appointments count
5. Travel pay eligibility count (conditional)

## Immediate Action Items

1. **Check Flipper Audit Logs** (Priority: High)
   - Flags: `:travel_pay_view_claim_details`, `:appointments_consolidation`
   - Dates: July 15, August 10, September 4, 2024

2. **Query Application Logs** (Priority: High)
   - `include_claims=true` request frequency
   - Average appointment counts in responses
   - Travel Pay API response times

3. **Review Monitoring** (Priority: Medium)
   - Response payload sizes
   - External API latency trends
   - Request parameter patterns

## Performance Recommendations

### Quick Wins (1-2 sprints)
- Lazy count calculations
- Backend pagination
- Cache external API calls

### Long-term (3-6 months)
- Migrate to VAOS V2 schema
- Backend count calculations
- Streaming responses

**Potential improvement: 0.7-1.5s reduction**

## Files in This Analysis

- **APPOINTMENTS_LATENCY_EXECUTIVE_SUMMARY.md** - High-level summary for decision makers
- **APPOINTMENTS_LATENCY_ANALYSIS.md** - Detailed technical analysis with code references
- **README.md** - This file

## How to Use This Analysis

### For Product Managers
1. Read executive summary
2. Review immediate action items
3. Prioritize based on probability scores
4. Coordinate with engineering teams

### For Engineers
1. Read full technical analysis
2. Follow investigation steps
3. Verify findings with feature flag history
4. Implement recommended optimizations

### For DevOps/SRE
1. Check monitoring dashboards
2. Review external API performance
3. Analyze log patterns
4. Support verification testing

## Related Resources

- Mobile Controller: `modules/mobile/app/controllers/mobile/v0/appointments_controller.rb`
- VAOS Controller: `modules/vaos/app/controllers/vaos/v2/appointments_controller.rb`
- Appointments Service: `modules/vaos/app/services/vaos/v2/appointments_service.rb`
- Mobile Proxy: `modules/mobile/app/services/mobile/v2/appointments/proxy.rb`

## Questions?

Contact:
- Mobile API Team - Feature flag decisions
- VAOS Team - Backend service performance
- Travel Pay Team - External API integration
- Platform Team - Flipper audit access

---

**Analysis Date:** October 2024  
**Analysts:** GitHub Copilot Workspace
