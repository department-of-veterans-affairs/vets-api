# Business Logic Questions: COE Error Handling Issue #2210

## Current Problem
The `status` and `submit_coe_claim` endpoints are experiencing high 5xx error rates because we're letting errors from the LGY service bubble up unhandled. When LGY returns a 404, our code raises an exception and returns a 500 error to the user.

## Proposed Technical Fix
Add 404 handling to two LGY service methods:
1. `get_determination` - called by the `status` endpoint
2. `put_application` - called by the `submit_coe_claim` endpoint

**This will prevent 404s from becoming 500 errors, BUT we need to decide what to do with those 404s.**

## Business Logic Questions

### Question 1: What does a 404 from `get_determination` mean?
When we call LGY to get a veteran's COE determination and LGY returns 404:
- What does this mean for the veteran?
- What should we show the user?
- What HTTP status should the `status` endpoint return?

**Important context**: We currently have a rule where if `get_determination` returns "ELIGIBLE" AND `get_application` returns 404, we treat that as "automatically eligible" (no application needed). 

**Question: Should we have a similar rule for `get_determination` returning 404?**
- Should a 404 from `get_determination` mean the veteran is **ineligible**?
- Or does it mean something else (e.g., no determination has been made yet)?
- Is this an expected scenario or an error condition?

### Question 2: What does a 404 from `put_application` mean?
When we try to submit a veteran's COE application to LGY and LGY returns 404:
- What does this mean? (We're passing the veteran's edipi as a query parameter - does this mean LGY can't find that edipi?)
- What should we show the veteran?
- Should they retry? Contact support?
- What HTTP status should the `submit_coe_claim` endpoint return?

## Why We Need Guidance
Once we handle these 404s (instead of letting them explode), we need to return meaningful responses to veterans and the frontend. We need product guidance on what these scenarios mean from a business perspective.
