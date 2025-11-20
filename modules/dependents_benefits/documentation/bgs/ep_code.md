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

### Gap-Finding
Query open claims, use gaps in sequence. Requires parsing all claims and understanding 55 claim types.

### Sequential
Force jobs to run one at a time. Simple but slower, less efficient.

## BGS Endpoints

### `findBenefitClaimTypeIncrement`
Returns next available incremental. Increments sequence by 1 each call (even if unused). Does not reserve or lock.

### `insertBenefitClaim`
Submits benefit claim. Requires unique incremental per veteran. Duplicate creates null dependency claim and error.

## References

**Code**:
- `lib/bgs/service.rb` (line 126)
- `app/sidekiq/bgs/submit_form686c_job.rb`
- `app/sidekiq/bgs/submit_form674_job.rb`
- [bgs-ext gem](https://github.com/department-of-veterans-affairs/bgs-ext/blob/9b76bf23abdb6ecd42c668f551c2cedcc4698864/lib/bgs/services/share_standard_data.rb#L20)
