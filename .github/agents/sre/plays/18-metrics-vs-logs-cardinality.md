---
id: metrics-vs-logs-cardinality
title: 'Understand Cardinality: Metrics vs Logs'
severity: HIGH
---

<!--
<agent_play>

  <context>
    Tagging StatsD with claim_id creates a new time series for every
    claim, causing the metrics database to grow unbounded. The dashboard
    times out trying to render thousands of unique series, making it
    impossible to see the aggregate "total claims processed" metric.
    Logs can handle millions of unique IDs but metrics cannot, so using
    the wrong tool produces unusable dashboards. When an engineer tags a
    metric with the entire params hash, infinite unique tag combinations
    exceed the cardinality limit.
  </context>

  <applies_to>
    <glob>app/sidekiq/**/*.rb</glob>
    <glob>modules/*/app/sidekiq/**/*.rb</glob>
    <glob>app/models/**/*.rb</glob>
    <glob>app/controllers/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="prefer-structured-logs" relationship="complementary" />
    <play id="dont-catch-log-reraise" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Use metrics (StatsD) for low-cardinality aggregations only —
      tags must have fewer than 100 unique values.
    </rule>
    <rule enforcement="must">
      Use logs for high-cardinality details — claim_id, user_id,
      request_id, file_path belong in structured log fields, not
      metric tags.
    </rule>
    <rule enforcement="must_not">
      Never tag metrics with claim_id, user_id, request_id,
      application_id, or any unique identifier.
    </rule>
    <rule enforcement="must_not">
      Never tag metrics with serialized hashes, JSON strings, or
      params objects — these have infinite cardinality.
    </rule>
    <rule enforcement="should">
      Calculate total cardinality before tagging: card_1 x card_2 x
      ... x card_n should be under 10,000 time series.
    </rule>
    <rule enforcement="should">
      When a tag value set is unbounded, whitelist known values and
      bucket unknowns as 'other'.
    </rule>
    <rule enforcement="verify">
      Review all `StatsD.increment` / `StatsD.histogram` calls: No
      tags with `claim_id`, `user_id`, `request_id`, or UUIDs
    </rule>
    <rule enforcement="verify">
      Calculate cardinality for each metric: Total < 10,000 time
      series
    </rule>
    <rule enforcement="verify">
      High-cardinality fields exist in logs, not metrics
    </rule>
    <rule enforcement="verify">
      Dashboards don't time out (sign of excessive cardinality)
    </rule>
    <rule enforcement="verify">
      Can search logs by high-cardinality fields (claim_id, user_id)
    </rule>
    <rule enforcement="verify">
      Can aggregate metrics by low-cardinality tags (status,
      form_type)
    </rule>
    <rule enforcement="verify">
      No serialized objects (params hash, JSON) in metric tags
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method containing the StatsD call to understand what the metric is tracking and what tags are being used.</step>
    <step>Identify which tags have high cardinality (unique IDs, serialized objects, variable-length combinations) vs low cardinality (status codes, form types, regions).</step>
    <step>Determine what questions the metric is intended to answer. "How many claims failed?" needs no claim_id tag. "Which claim failed?" needs logs.</step>
    <step>Check whether the high-cardinality data is already being logged elsewhere in the method. If not, a log line must be added as part of the fix.</step>
    <step>Calculate the total cardinality: multiply unique values across all tags. If the product exceeds 10,000, the metric needs tag reduction.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>StatsD call tags include serialized params hash or JSON —
infinite cardinality that can crash the metrics system</critical>
    <critical>StatsD call tags include both a high-cardinality ID and
another high-cardinality dimension — multiplicative explosion</critical>
    <high>StatsD call tags include claim_id, user_id, request_id, or any
unique identifier</high>
    <high>StatsD call tags include variable-length combination strings
(benefit lists, feature flags)</high>
    <medium>StatsD call tags include values from an unbounded set that
could grow beyond 100 unique values</medium>
  </severity_assessment>

  <pr_comment_template>
    **Understand Cardinality: Metrics vs Logs** | `HIGH`

    `{{file_path}}:{{line_number}}` — StatsD metric tagged with `{{high_cardinality_tag}}` (high cardinality: {{estimated_unique_values}} unique values)

    **Why this matters:** Each unique tag value creates a new time series in the
    metrics database. With {{estimated_unique_values}} unique values, this metric
    produces {{estimated_unique_values}} time series that grow unbounded.
    Dashboards time out rendering all series, and aggregate queries become
    impossible.

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
  </pr_comment_template>

</agent_play>
-->

### Do

- Use metrics (StatsD) for low-cardinality aggregations only -- tags must have fewer than 100 unique values:
  ```ruby
  StatsD.increment('claim.submitted',
    tags: [
      "form_type:#{claim.form_type}",  # ~50 values
      "status:#{claim.status}"         # ~5 values
    ]
  )
  ```
- Use logs for high-cardinality details (`claim_id`, `user_id`, `request_id`):
  ```ruby
  Rails.logger.info('Claim submitted',
    claim_id: claim.id,
    user_id: user.id,
    form_type: claim.form_type
  )
  ```

### Don't

- Tag metrics with `claim_id`, `user_id`, `request_id`, or any unique identifier:
  ```ruby
  # BAD: each claim_id creates a new time series
  StatsD.increment("key", tags: ["claim_id:#{claim_id}"])
  ```
- Tag metrics with serialized hashes, JSON strings, or params objects:
  ```ruby
  # BAD: infinite cardinality -- no two executions produce identical params
  StatsD.increment("key", tags: ["params:#{params}"])
  ```

## Anti-Patterns

#### Anti-Pattern #1: Claim ID in Metric Tags (CRITICAL)

```ruby
sidekiq_retries_exhausted do |msg, _e|
  claim_id = msg['args'][0]
  # BAD: Each claim_id creates new time series
  StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left",
                   tags: ["claim_id:#{claim_id}"])

  claim = SavedClaim::CaregiversAssistanceClaim.find(claim_id)
  send_failure_email(claim)
end
```

```ruby
# GOOD: Metrics track aggregate count (no claim_id tag)
StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left")

# GOOD: Logs capture specific claim_id for debugging
Rails.logger.error('Retries exhausted for claim',
  claim_id: claim_id,
  statsd_key: "#{STATSD_KEY_PREFIX}failed_no_retries_left"
)
```

#### Anti-Pattern #2: Entire Params Hash in Metric Tags (CATASTROPHIC)

```ruby
def notify(params)
  retry_count = Integer(params['retry_count']) + 1
  claim_id = params['args'][0]

  StatsD.increment("#{STATSD_KEY_PREFIX}applications_retried") if retry_count == 1
  if retry_count == 10
    # CATASTROPHIC: Entire params hash + claim_id in tags
    StatsD.increment("#{STATSD_KEY_PREFIX}failed_ten_retries",
                     tags: ["params:#{params}", "claim_id:#{claim_id}"])
  end
end
```

```ruby
# GOOD: Metrics track retry count only (low cardinality)
StatsD.increment("#{STATSD_KEY_PREFIX}failed_ten_retries")

# GOOD: Logs capture full params for debugging
Rails.logger.error('Job failed after ten retries',
  retry_count: retry_count,
  claim_id: claim_id,
  job_params: params  # Full details in logs
)
```

#### Anti-Pattern #3: Variable Benefit Combinations in Tags

```ruby
def perform(user_uuid, service_history)
  # ... fetch eligible benefits for user ...
  eligible_benefits = service.get_eligible_benefits(prepared_params)
  sorted_benefits = sort_benefits(eligible_benefits)
  formatted_benefits = format_benefits(sorted_benefits)

  # BAD: Each user has different benefit combination
  StatsD.increment('benefits_discovery_logging',
                   tags: ["eligible_benefits:#{formatted_benefits}"])
end
```

```ruby
# GOOD: Metrics track total count
StatsD.increment('benefits_discovery_logging')

# GOOD: Logs capture specific benefits for user
Rails.logger.info('Benefits discovery completed',
  user_uuid: user_uuid,
  eligible_benefits: formatted_benefits,  # Full details in logs
  benefit_count: eligible_benefits.size
)
```

#### Anti-Pattern #4: Flash Text in Tags

```ruby
def log_flashes
  flash_prototypes = FLASH_PROTOTYPES & flashes
  flashes.each do |flash|
    # BAD: Flash text is variable string
    StatsD.increment(FLASHES_STATSD_KEY,
                     tags: ["flash:#{flash}", "prototype:#{flash_prototypes.include?(flash)}"])
  end
end
```

```ruby
# GOOD: Only use known flash types as tags
KNOWN_FLASH_TYPES = ['ALSO', 'PACT_ACT', 'PRESUMPTIVE'].freeze

def log_flashes
  flashes.each do |flash|
    # Use 'other' for unknown flash types
    flash_tag = KNOWN_FLASH_TYPES.include?(flash) ? flash : 'other'

    StatsD.increment(FLASHES_STATSD_KEY,
                     tags: ["flash:#{flash_tag}"])

    # Log exact flash text for debugging
    Rails.logger.info('Flash added to claim',
      flash: flash,
      submitted_claim_id: submitted_claim_id
    )
  end
end
```
