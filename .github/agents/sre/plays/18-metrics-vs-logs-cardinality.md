# Play 18: Understand Cardinality: Metrics vs Logs

## Context
Tagging StatsD with claim_id creates a new time series for every claim, causing the metrics database to grow unbounded. The dashboard times out trying to render thousands of unique series, making it impossible to see the aggregate "total claims processed" metric. Logs can handle millions of unique IDs but metrics cannot, so using the wrong tool produces unusable dashboards. When an engineer tags a metric with the entire params hash, infinite unique tag combinations exceed the cardinality limit.

## Applies To
- `app/sidekiq/**/*.rb`
- `modules/*/app/sidekiq/**/*.rb`
- `app/models/**/*.rb`
- `app/controllers/**/*.rb`
- `lib/**/*.rb`

## Investigation Steps
1. Read the full method containing the StatsD call to understand what the metric is tracking and what tags are being used.
2. Identify which tags have high cardinality (unique IDs, serialized objects, variable-length combinations) vs low cardinality (status codes, form types, regions).
3. Determine what questions the metric is intended to answer. "How many claims failed?" needs no claim_id tag. "Which claim failed?" needs logs.
4. Check whether the high-cardinality data is already being logged elsewhere in the method. If not, a log line must be added as part of the fix.
5. Calculate the total cardinality: multiply unique values across all tags. If the product exceeds 10,000, the metric needs tag reduction.

## Severity Assessment
- **CRITICAL:** StatsD call tags include serialized params hash or JSON -- infinite cardinality that can crash the metrics system
- **CRITICAL:** StatsD call tags include both a high-cardinality ID and another high-cardinality dimension -- multiplicative explosion
- **HIGH:** StatsD call tags include claim_id, user_id, request_id, or any unique identifier
- **HIGH:** StatsD call tags include variable-length combination strings (benefit lists, feature flags)
- **MEDIUM:** StatsD call tags include values from an unbounded set that could grow beyond 100 unique values

## Golden Patterns

### Do
Use metrics (StatsD) for low-cardinality aggregations only -- tags must have fewer than 100 unique values:
```ruby
StatsD.increment('claim.submitted',
  tags: [
    "form_type:#{claim.form_type}",  # ~50 values
    "status:#{claim.status}"         # ~5 values
  ]
)
```

Use logs for high-cardinality details (`claim_id`, `user_id`, `request_id`):
```ruby
Rails.logger.info('Claim submitted',
  claim_id: claim.id,
  user_id: user.id,
  form_type: claim.form_type
)
```

### Don't
Tag metrics with `claim_id`, `user_id`, `request_id`, or any unique identifier:
```ruby
# BAD: each claim_id creates a new time series
StatsD.increment("key", tags: ["claim_id:#{claim_id}"])
```

Tag metrics with serialized hashes, JSON strings, or params objects:
```ruby
# BAD: infinite cardinality -- no two executions produce identical params
StatsD.increment("key", tags: ["params:#{params}"])
```

## Anti-Patterns

### Claim ID in Metric Tags
**Anti-pattern:**
```ruby
sidekiq_retries_exhausted do |msg, _e|
  claim_id = msg['args'][0]
  StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left",
                   tags: ["claim_id:#{claim_id}"])
end
```
**Problem:** Thousands of unique claim_ids created daily. Each claim_id is a new time series. Cannot answer "How many retries exhausted today?" because data is fragmented across thousands of series. Dashboards time out trying to aggregate.

**Corrected:**
```ruby
# Metrics track aggregate count (no claim_id tag)
StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left")

# Logs capture specific claim_id for debugging
Rails.logger.error('Retries exhausted for claim',
  claim_id: claim_id,
  statsd_key: "#{STATSD_KEY_PREFIX}failed_no_retries_left"
)
```

### Entire Params Hash in Metric Tags
**Anti-pattern:**
```ruby
def notify(params)
  retry_count = Integer(params['retry_count']) + 1
  claim_id = params['args'][0]

  if retry_count == 10
    StatsD.increment("#{STATSD_KEY_PREFIX}failed_ten_retries",
                     tags: ["params:#{params}", "claim_id:#{claim_id}"])
  end
end
```
**Problem:** `params` is the entire Sidekiq job params hash serialized to string. Every single job execution creates a unique params string. Infinite cardinality -- no two executions have identical params. This single line could create millions of unique time series.

**Corrected:**
```ruby
# Metrics track retry count only (low cardinality)
StatsD.increment("#{STATSD_KEY_PREFIX}failed_ten_retries")

# Logs capture full params for debugging
Rails.logger.error('Job failed after ten retries',
  retry_count: retry_count,
  claim_id: claim_id,
  job_params: params
)
```

### Variable Benefit Combinations in Tags
**Anti-pattern:**
```ruby
def perform(user_uuid, service_history)
  eligible_benefits = service.get_eligible_benefits(prepared_params)
  sorted_benefits = sort_benefits(eligible_benefits)
  formatted_benefits = format_benefits(sorted_benefits)

  StatsD.increment('benefits_discovery_logging',
                   tags: ["eligible_benefits:#{formatted_benefits}"])
end
```
**Problem:** `formatted_benefits` is a string like `"education:GI_Bill/healthcare:CHAMPVA/disability:compensation"`. Different veterans have different benefit combinations -- hundreds or thousands of unique combinations possible. Each combination creates a new time series.

**Corrected:**
```ruby
# Metrics track total count
StatsD.increment('benefits_discovery_logging')

# Logs capture specific benefits for user
Rails.logger.info('Benefits discovery completed',
  user_uuid: user_uuid,
  eligible_benefits: formatted_benefits,
  benefit_count: eligible_benefits.size
)
```

### Flash Text in Tags
**Anti-pattern:**
```ruby
def log_flashes
  flash_prototypes = FLASH_PROTOTYPES & flashes
  flashes.each do |flash|
    StatsD.increment(FLASHES_STATSD_KEY,
                     tags: ["flash:#{flash}", "prototype:#{flash_prototypes.include?(flash)}"])
  end
end
```
**Problem:** `flash` is arbitrary string (medical condition, claim type, special handling note). If flash values are unbounded, cardinality explodes.

**Corrected:**
```ruby
KNOWN_FLASH_TYPES = ['ALSO', 'PACT_ACT', 'PRESUMPTIVE'].freeze

def log_flashes
  flashes.each do |flash|
    flash_tag = KNOWN_FLASH_TYPES.include?(flash) ? flash : 'other'

    StatsD.increment(FLASHES_STATSD_KEY,
                     tags: ["flash:#{flash_tag}"])

    Rails.logger.info('Flash added to claim',
      flash: flash,
      submitted_claim_id: submitted_claim_id
    )
  end
end
```

## Finding Template
**Understand Cardinality: Metrics vs Logs** | `HIGH`

`{{file_path}}:{{line_number}}` -- StatsD metric tagged with `{{high_cardinality_tag}}` (high cardinality: {{estimated_unique_values}} unique values)

**Why this matters:** Each unique tag value creates a new time series in the metrics database. With {{estimated_unique_values}} unique values, this metric produces {{estimated_unique_values}} time series that grow unbounded. Dashboards time out rendering all series, and aggregate queries become impossible.

**Suggested fix:**
```ruby
# Metrics: remove high-cardinality tag
{{metric_code_without_high_card_tag}}

# Logs: capture high-cardinality data for debugging
{{log_line_with_high_card_data}}
```

- [ ] No high-cardinality IDs in metric tags
- [ ] High-cardinality data captured in structured log line
- [ ] Total cardinality across all tags < 10,000 time series

[Play: Understand Cardinality: Metrics vs Logs](plays/metrics-vs-logs-cardinality.md)

## Verify Commands
```bash
# No claim_id in metric tags in changed file
grep -On 'StatsD\.\w+.*tags:.*claim_id' {{file_path}} && exit 1 || exit 0

# No user_id in metric tags in changed file
grep -On 'StatsD\.\w+.*tags:.*user_id' {{file_path}} && exit 1 || exit 0

# No params in metric tags in changed file
grep -On 'StatsD\.\w+.*tags:.*params' {{file_path}} && exit 1 || exit 0

# No request_id in metric tags in changed file
grep -On 'StatsD\.\w+.*tags:.*request_id' {{file_path}} && exit 1 || exit 0

# Run specs for changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: prefer-structured-logs (complementary)
- Play: dont-catch-log-reraise (complementary)
