# BGS EP Code and Incremental Rules

Rules, constraints, and limitations for working with EP codes and incrementals in BGS submissions for 686c and 674 forms.

## Duplicate Claims Error

**Error**: `"Duplicate Benefit Claims found on the Corporate Database"`

**Cause**: Multiple claims submitted with same `incremental` value, creating null dependency claims.

## Incremental Rules

### Per-Veteran Sequence
- Each veteran has own sequence starting at "130"
- Each successful `insertBenefitClaim` increments by 1
- `findBenefitClaimTypeIncrement` returns next value

### Uniqueness Requirement
Every `insertBenefitClaim` must have unique incremental per veteran. Violations cause duplicate error and null dependency claim.

### Race Condition
Parallel jobs fetching incrementals independently can receive same value:

1. Job A fetches "130"
2. Job B fetches "130" (before A completes insert)
3. Job A inserts with "130"
4. Job B inserts with "130" -> Duplicate error

## System Constraints

### Open Claims Limit
~9 open claims per veteran maximum. VA.gov allows up to 20 students, so must consolidate 674 submissions.

### Claim Types
55 different "130" claim types (including 686c and 674) share the same per-veteran incremental sequence.

## Management Strategies

### Gap-Finding (Current Implementation)
Query open claims, use gaps in sequence. Our implementation:
1. Query active EP codes via `find_active_benefit_claim_type_increments` (queries all open claims from BGS)
2. Query pending sibling submission attempts (checks other parallel jobs)
3. Select from available pool: `[130, 131, 132, 134, 136, 137, 138, 139] - active_ep_codes`
4. Pass selected EP code to submission job
5. Job uses EP code in `BGSV2::VnpVeteran#create` for `insertBenefitClaim`

**Advantage**: Allows parallel execution while avoiding duplicates  
**Trade-off**: Requires coordination between jobs via database

### Sequential (Alternative)
Force jobs to run one at a time. Simple but slower, less efficient.

## BGS Endpoints

### `findBenefitClaimTypeIncrement`
Returns next available incremental. Increments sequence by 1 each call (even if unused). Does not reserve or lock.

**Used by**: Fallback in `BGSV2::VnpVeteran#create` if EP code not provided or if first attempt fails

### `findClaimsDetailsByParticipantId`
Returns all claims for veteran including EP codes and status.

**Wrapped by**: `BGSV2::Service#find_active_benefit_claim_type_increments` - filters to active claims, extracts EP codes

### `insertBenefitClaim`
Submits benefit claim. Requires unique incremental per veteran. Duplicate creates null dependency claim and error.

**Used by**: `BGSV2::VnpVeteran#create_veteran_response` via `veteran.veteran_response` - passes `claim_type_end_product`

## References

**Code**:
- **EP Code Selection**: `modules/dependents_benefits/lib/dependents_benefits/sidekiq/bgs_form_job.rb`
  - `active_claim_ep_codes` - queries BGS via `find_active_benefit_claim_type_increments`
  - `active_sibling_ep_codes` - queries pending submission attempts
  - `available_claim_type_end_product_codes` - calculates available codes
- **EP Code Usage**: `lib/bgsv2/vnp_veteran.rb`
  - `initialize` - receives `claim_type_end_product` from job
  - `create` - uses EP code in `veteran_response` for `insertBenefitClaim`
  - Fallback to `find_benefit_claim_type_increment` if not provided or on retry
- **BGS Service**: `lib/bgsv2/service.rb`
  - `find_active_benefit_claim_type_increments` - queries active claims, extracts EP codes
  - `find_benefit_claim_type_increment` - fetches next sequential EP code from BGS
- **Legacy Code**:
  - `lib/bgs/service.rb` (line 126)
  - `app/sidekiq/bgs/submit_form686c_job.rb`
  - `app/sidekiq/bgs/submit_form674_job.rb`
- **External**: [bgs-ext gem](https://github.com/department-of-veterans-affairs/bgs-ext/blob/9b76bf23abdb6ecd42c668f551c2cedcc4698864/lib/bgs/services/share_standard_data.rb#L20)
