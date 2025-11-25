# Logstop Performance Benchmark - BEFORE (Global Filtering)

## Test Configuration
- **Iterations:** 10,000
- **Log messages per iteration:** 10 realistic vets-api logs
- **Total operations:** 100,000
- **Implementation:** Global filtering via `Logstop.guard(Rails.logger, ...)`

---

## Performance Measurements

### 1. Baseline (no filtering)
- Total time: **5.11ms**
- Per line: **0.05µs**

### 2. Logstop built-in patterns only
- Total time: **161.64ms**
- Per line: **1.62µs**
- **Overhead: +3,064%** (30x slower)

### 3. VA custom scrubber (Logstop + VA patterns)
- Total time: **258.22ms**
- Per line: **2.58µs**
- **Overhead: +4,954%** (50x slower)

### 4. Large payload (5KB)
- Baseline: **0.04ms** for 1,000 payloads
- Filtered: **72.0ms** for 1,000 payloads
- Per payload: **0.072ms**
- **Overhead: +199,891%**

---

## Production Impact Estimates

**Per line overhead:** 2.53µs

| Volume | Extra CPU Time per Day |
|--------|------------------------|
| 1M logs/day | +2.53 seconds |
| 10M logs/day | +25.31 seconds |
| 100M logs/day | +253.11 seconds (4.2 minutes) |

---

## Recommendation

**✗ HIGH IMPACT (>2000% overhead)**

**Strongly recommend opt-in only** - not suitable for global filtering at scale.

---

## Technical Details

### Implementation (Global)
```ruby
# config/initializers/logstop.rb
Logstop.guard(Rails.logger, scrubber: VAPiiScrubber.custom_scrubber)
```

This approach applies filtering to **ALL** `Rails.logger` calls automatically, which causes the high overhead shown above.

### Next Step
Implement opt-in model where developers explicitly choose to use filtered logging only in sensitive contexts.
