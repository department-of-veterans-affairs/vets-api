# Logstop Performance Analysis & Recommendations

## Executive Summary

**Benchmark results show HIGH performance impact (5600% overhead). Recommend opt-in approach only for sensitive log contexts.**

## Performance Benchmark Results

Ran 10,000 iterations on 10 realistic vets-api log messages:

| Test | Time | Per Log Line | Overhead |
|------|------|-------------|----------|
| Baseline (no filtering) | 4.32ms | 0.04µs | - |
| Logstop built-in only | 170.1ms | 1.7µs | **3,841%** |
| Logstop + VA patterns | 248.8ms | 2.49µs | **5,665%** |
| Large payload (5KB) | 102.07ms | 0.1ms/payload | **364,439%** |

## Key Findings

### 1. High CPU Overhead
- Each log line adds **2.49µs overhead** (58x slower)
- Large JSON payloads (5KB) add **0.1ms overhead** per log
- Regex pattern matching is expensive at scale

### 2. Volume Impact
Assuming vets-api logs **10M lines/day** (conservative estimate):
- **Additional CPU time:** 24.9 seconds/day of regex processing
- **For 100M logs/day:** 4.1 minutes/day of pure regex overhead

### 3. Large Payload Problem
If VFS teams log large API responses (common for debugging):
- A 5KB payload takes **0.1ms** to filter
- 1000 large payloads = **100ms** of blocking regex processing
- This is **I/O bound** code doing **CPU intensive** work

### 4. False Positives Confirmed

Trevor's feedback identified:
- **10-digit pattern filters Unix timestamps** (e.g., `1732478261`)
- **9-digit pattern filters IDs** that happen to be 9 digits
- These are aggressive patterns with high false positive rates

## Recommendations

### Option 1: Opt-In Only (RECOMMENDED)
**Do NOT guard Rails.logger globally.** Instead:

```ruby
# config/initializers/logstop.rb
module VAPiiLogger
  def self.filtered
    @filtered ||= begin
      logger = ActiveSupport::Logger.new(STDOUT)
      Logstop.guard(logger, scrubber: VAPiiScrubber.custom_scrubber)
      logger
    end
  end
end

# Usage in controllers/services
VAPiiLogger.filtered.info("User submitted claim with data: #{params}")
```

**Pros:**
- Zero performance impact on existing logs
- Developers explicitly choose when to use PII filtering
- Can be used for specific sensitive contexts (PII-heavy controllers)

**Cons:**
- Requires developer awareness
- Won't catch accidental PII in existing `Rails.logger` calls

### Option 2: Remove Aggressive Patterns
Keep only low false-positive patterns:
- ✅ SSN with dashes (XXX-XX-XXXX) - Logstop built-in, very specific
- ✅ Email addresses - Logstop built-in, specific format
- ✅ Phone numbers - Logstop built-in, specific format
- ✅ Credit cards - Logstop built-in, specific format
- ✅ VA file numbers - Our pattern requires context ("VA file #...")
- ❌ **REMOVE:** 9-digit pattern (too broad, filters IDs)
- ❌ **REMOVE:** 10-digit pattern (too broad, filters timestamps)

This reduces overhead from **5,665%** to **~3,841%** (still high).

### Option 3: Feature Flag + Opt-In
Combine approaches:
```ruby
# Only guard if explicitly enabled
if Flipper.enabled?(:logstop_global_filtering)
  Logstop.guard(Rails.logger, scrubber: VAPiiScrubber.custom_scrubber)
end

# Always provide opt-in filtered logger
module VAPiiLogger
  def self.filtered
    # ... opt-in logger
  end
end
```

### Option 4: Async Filtering (Advanced)
Post-process logs asynchronously:
- Logs write unfiltered (fast)
- Background job filters logs before shipping to DataDog/CloudWatch
- Requires infrastructure changes

**Not recommended for initial implementation.**

## Response to Feedback

### Trevor's Concerns
> "Any 10 digit pattern will be filtered???"

**Valid concern.** The 10-digit EDIPI pattern is too aggressive and filters:
- Unix timestamps (10 digits)
- Order numbers
- Transaction IDs

**Recommendation:** Remove 10-digit and 9-digit patterns, keep only context-aware patterns.

### Lindsey's Concerns
> "Performance impact of running Logstop's scrubbing on every log line"

**Valid concern confirmed.** Benchmark shows:
- 5,665% overhead for all patterns
- 0.1ms overhead for 5KB payloads
- Blocking I/O with CPU-intensive regex

**Recommendation:** Opt-in only, not global.

### Kyle's Suggestion
> "Just proposing adding it as an OPTION, not forcing all logs through it?"

**Exactly right.** Should be opt-in, not automatic.

## Proposed Implementation Changes

### Immediate Changes Needed

1. **Remove global guard** - Don't call `Logstop.guard(Rails.logger, ...)`
2. **Remove aggressive patterns** - Remove 9-digit and 10-digit matchers
3. **Provide opt-in logger:**

```ruby
# config/initializers/logstop.rb
module VAPiiLogger
  # Filtered logger for sensitive contexts only
  def self.filtered
    @filtered ||= begin
      logger = ActiveSupport::Logger.new(STDOUT)
      # Only keep low false-positive patterns
      scrubber = lambda do |msg|
        Logstop.scrub(msg) # Built-in patterns: SSN, email, phone, credit card
        # No custom patterns - too high false positive rate
      end
      Logstop.guard(logger, scrubber: scrubber)
      logger
    end
  end
end
```

4. **Document usage:**
```ruby
# When logging potentially sensitive data
VAPiiLogger.filtered.info("User submitted: #{params}")

# Normal logging (no filtering, no overhead)
Rails.logger.info("Processing request")
```

### Documentation for VFS Teams

Create docs explaining:
- When to use `VAPiiLogger.filtered` vs `Rails.logger`
- Performance tradeoff (~2.5µs overhead per log)
- What patterns are filtered

## Alternative: ParameterFilterHelper Improvement

Instead of Logstop, enhance existing `ParameterFilterHelper`:

```ruby
# Before logging
filtered_data = ParameterFilterHelper.filter_params(sensitive_hash)
Rails.logger.info("User data: #{filtered_data}")
```

**Pros:**
- Zero regex overhead on strings
- Reuses existing filtering logic
- Developers already familiar with it

**Cons:**
- Only works on Hash/params, not strings
- Won't catch "My SSN is 123-45-6789" typed in comments

## Final Recommendation

**For this PR:**
1. Make it opt-in only (`VAPiiLogger.filtered`)
2. Keep only Logstop built-in patterns (no custom 9/10-digit patterns)
3. Document performance impact and usage guidelines
4. Add benchmark to PR description

**For future consideration:**
- Async log filtering in CI/CD pipeline
- Static analysis to detect PII in code
- Enhanced `ParameterFilterHelper` for structured logging

## Next Steps

1. Update PR to make opt-in only
2. Remove aggressive numeric patterns
3. Add benchmark results to PR description
4. Solicit feedback from leadership with performance data
5. Document usage in Platform docs

---

**Benchmark Script:** `/Research/docs/logstop-performance-benchmark.rb`
**Run with:** `ruby Research/docs/logstop-performance-benchmark.rb`
