---
id: metrics-vs-logs-cardinality
title: 'Understand Cardinality: Metrics vs Logs'
version: 1
severity: HIGH
category: observability
tags:
- cardinality
- statsd
- metrics
- time-series
- high-cardinality
- datadog
language: ruby
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

  <retrieval_triggers>
    <trigger>StatsD metric tagged with claim_id or user_id</trigger>
    <trigger>high cardinality tags creating too many time series</trigger>
    <trigger>dashboard times out rendering metric data</trigger>
    <trigger>params hash in metric tags creates infinite cardinality</trigger>
    <trigger>when to use metrics vs logs for tracking</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="claim_id_in_metric_tags" confidence="high">
      <signature>StatsD\.\w+.*tags:.*claim_id</signature>
      <description>
        A StatsD metric call that includes `claim_id` in its tags.
        Each unique claim ID creates a new time series. Thousands of
        claims per day means thousands of time series, causing
        unbounded growth in the metrics database and dashboard
        timeouts.
      </description>
      <example>StatsD.increment("key", tags: ["claim_id:#{claim_id}"])</example>
      <example>StatsD.histogram("key", value, tags: ["claim_id:#{claim.id}"])</example>
    </pattern>
    <pattern name="user_id_in_metric_tags" confidence="high">
      <signature>StatsD\.\w+.*tags:.*user_id</signature>
      <description>
        A StatsD metric call that includes `user_id` in its tags. User
        IDs have millions of unique values. Each unique user_id
        creates a separate time series, making dashboards unusable and
        metrics databases grow unbounded.
      </description>
      <example>StatsD.increment("key", tags: ["user_id:#{user.id}"])</example>
      <example>StatsD.histogram("key", value, tags: ["user_id:#{user_uuid}"])</example>
    </pattern>
    <pattern name="params_in_metric_tags" confidence="high">
      <signature>StatsD\.\w+.*tags:.*params</signature>
      <description>
        A StatsD metric call that includes a params hash or params-
        derived value in its tags. Serialized params hashes have
        infinite cardinality — no two job executions produce identical
        params strings. This single pattern can create millions of
        unique time series.
      </description>
      <example>StatsD.increment("key", tags: ["params:#{params}"])</example>
      <example>StatsD.increment("key", tags: ["params:#{params}", "claim_id:#{claim_id}"])</example>
    </pattern>
    <pattern name="request_id_in_metric_tags" confidence="high">
      <signature>StatsD\.\w+.*tags:.*request_id</signature>
      <description>
        A StatsD metric call that includes `request_id` in its tags.
        Request IDs are UUIDs with unbounded cardinality. Every
        request creates a new time series, making the metric useless
        for aggregation.
      </description>
      <example>StatsD.increment("key", tags: ["request_id:#{request.uuid}"])</example>
    </pattern>
    <heuristic>
      A StatsD call with tags containing string interpolation of an
      ID field (claim_id, user_id, application_id, uuid) is a strong
      signal of high-cardinality metric tagging. The interpolated
      value likely has thousands or millions of unique values.
    </heuristic>
    <heuristic>
      A StatsD call where a tag value comes from a method return or
      variable that represents a collection of user-specific data
      (benefits list, params hash, form data) indicates variable-
      combination cardinality. The number of unique tag values grows
      with the number of users.
    </heuristic>
    <heuristic>
      A StatsD call inside a loop that processes individual records
      (claims, applications, users) where the loop variable is used
      in tags indicates per-record metric tagging. Each iteration
      creates a new time series.
    </heuristic>
    <false_positive>
      A StatsD call with tags that use a known, bounded set of
      values — such as `form_type`, `status`, `region`, or
      `environment` — is not a violation. These are low-cardinality
      dimensions suitable for metric tagging. The key test: can you
      enumerate all possible values, and is that count under 100?
    </false_positive>
    <false_positive>
      A StatsD call where the tag value is explicitly whitelisted or
      bucketed (e.g., `flash_tag = KNOWN_TYPES.include?(val) ? val :
      'other'`) is acceptable. The whitelist bounds the cardinality
      regardless of input data.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect a high-cardinality metric tagging violation
    with high confidence, compose a PR comment that includes: 1.
    The specific violation (which tag has high cardinality and
    why) 2. The cardinality impact (estimated number of time
    series created) 3. A concrete code suggestion: remove the
    high-cardinality tag from the StatsD call and add a structured
    log line capturing the same data 4. The golden pattern showing
    metrics + logs separation 5. A link to this play for full
    context Do not simply flag the violation — provide the fix
    with both the metric correction and the log line addition.
  </default_to_action>

  <verify>
    <command description="No claim_id in metric tags in changed file">
      grep -On 'StatsD\.\w+.*tags:.*claim_id' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No user_id in metric tags in changed file">
      grep -On 'StatsD\.\w+.*tags:.*user_id' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No params in metric tags in changed file">
      grep -On 'StatsD\.\w+.*tags:.*params' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No request_id in metric tags in changed file">
      grep -On 'StatsD\.\w+.*tags:.*request_id' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

  <anti_pattern_sources>
    <source name="Claim ID in Metric Tags" file="app/sidekiq/form1010cg/submission_job.rb:48" url="https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/form1010cg/submission_job.rb#L48" />
    <source name="Entire Params Hash in Metric Tags" file="app/sidekiq/form1010cg/submission_job.rb:65-66" url="https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/form1010cg/submission_job.rb#L65-L66" />
    <source name="Variable Benefit Combinations in Tags" file="app/sidekiq/lighthouse/benefits_discovery/log_eligible_benefits_job.rb:28" url="https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/lighthouse/benefits_discovery/log_eligible_benefits_job.rb#L28" />
    <source name="Flash Text in Tags" file="app/models/concerns/form526_claim_fast_tracking_concern.rb:340" url="https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/concerns/form526_claim_fast_tracking_concern.rb#L340" />
  </anti_pattern_sources>

</agent_play>
-->

# Understand Cardinality: Metrics vs Logs

This play teaches you when to use metrics (StatsD) vs logs for tracking data, based on the cardinality of the values you need to record.

> [!CAUTION]
> One metric with high-cardinality tags creates thousands of time series, making dashboards unusable.

## Why It Matters

When you tag a StatsD metric with `claim_id`, you create a new time series for every claim. Thousands of claims per day means thousands of time series, causing the metrics database to grow unbounded and dashboards to time out. When you tag a metric with the entire params hash, every single job execution creates a unique tag combination -- infinite cardinality that can crash the metrics system. Logs handle millions of unique IDs efficiently because their cost scales with volume (bytes ingested), not with unique values. Using the wrong tool for high-cardinality data produces unusable dashboards and makes aggregate questions ("How many claims failed today?") unanswerable.

## Guidance

Use metrics for aggregate questions with low-cardinality dimensions (status codes, form types, regions) and use logs for individual record details (claim_id, user_id, request_id). Before adding a tag to a metric, ask: "Can I enumerate all possible values, and is that count under 100?" If not, the data belongs in a structured log field.

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

### Anti-Patterns from vets-api

#### Anti-Pattern #1: Claim ID in Metric Tags (CRITICAL)

**File**: [app/sidekiq/form1010cg/submission_job.rb:48](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/form1010cg/submission_job.rb#L48)

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

**Also found at**:

- [app/sidekiq/form1010cg/submission_job.rb:83](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/form1010cg/submission_job.rb#L83) - `tags: ["claim_id:#{claim_id}"]`
- [app/sidekiq/form1010cg/submission_job.rb:116](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/form1010cg/submission_job.rb#L116) - `tags: ["claim_id:#{claim.id}"]`

**Why this is bad:**

- **Thousands of unique claim_ids** created daily
- Each claim_id = new time series for metric `failed_no_retries_left`
- Cannot answer "How many retries exhausted today?" (data fragmented across thousands of series)
- Dashboards time out trying to aggregate thousands of series
- Metrics database grows unbounded (claim IDs never repeat)

**What should happen:**

```ruby
# GOOD: Metrics track aggregate count (no claim_id tag)
StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left")

# GOOD: Logs capture specific claim_id for debugging
Rails.logger.error('Retries exhausted for claim',
  claim_id: claim_id,
  statsd_key: "#{STATSD_KEY_PREFIX}failed_no_retries_left"
)
```

---

#### Anti-Pattern #2: Entire Params Hash in Metric Tags (CATASTROPHIC)

**File**: [app/sidekiq/form1010cg/submission_job.rb:65-66](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/form1010cg/submission_job.rb#L65-L66)

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

**Why this is catastrophic:**

- `params` is the **entire Sidekiq job params hash** serialized to string
- Includes: job ID, timestamps, retry count, arguments, error messages
- **Every single job execution** creates a unique params string
- **Infinite cardinality** - no two executions have identical params
- Metrics system rejects metric or randomly drops data
- This single line could create millions of unique time series

**What should happen:**

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

---

#### Anti-Pattern #3: Variable Benefit Combinations in Tags

**File**: [app/sidekiq/lighthouse/benefits_discovery/log_eligible_benefits_job.rb:28](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/lighthouse/benefits_discovery/log_eligible_benefits_job.rb#L28)

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

**Why this is bad:**

- `formatted_benefits` is a string like: `"education:GI_Bill/healthcare:CHAMPVA/disability:compensation"`
- Different veterans have different benefit combinations
- Hundreds or thousands of unique combinations possible
- Each combination = new time series
- Cannot answer "How many benefit discoveries ran today?" (data fragmented)

**What should happen:**

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

---

#### Anti-Pattern #4: Flash Text in Tags

**File**: [app/models/concerns/form526_claim_fast_tracking_concern.rb:340](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/concerns/form526_claim_fast_tracking_concern.rb#L340)

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

**Why this is potentially bad:**

- `flash` is arbitrary string (medical condition, claim type, special handling note)
- If flash values are unbounded (user-generated or many unique types), cardinality explodes
- Better to use a **whitelist** of known flash types or aggregate differently

**What should happen:**

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

## Reference

### Understanding Cardinality

#### What is Cardinality?

**Cardinality** = number of unique values in a dimension

| Field | Cardinality | Example Values |
|-------|-------------|----------------|
| HTTP status code | Low (~10) | `200`, `404`, `500`, `502` |
| Form type | Low (~50) | `526`, `1010cg`, `21-526EZ` |
| Claim ID | High (millions) | `claim_abc123`, `claim_def456` |
| User UUID | High (millions) | `user_789012`, `user_345678` |
| Request ID | High (unbounded) | `req_uuid1`, `req_uuid2` |
| Region | Low (~5) | `us-east`, `us-west`, `eu-central` |

#### How Metrics and Logs Handle Cardinality Differently

```
┌─────────────────────────────────────────────────────────────┐
│  Metrics (StatsD, Prometheus, Datadog Metrics)              │
│                                                              │
│  Storage Model: TIME SERIES                                 │
│  - Each unique tag combination = separate time series       │
│  - Cost: O(cardinality₁ × cardinality₂ × ... × cardinalityₙ)│
│  - Exponential explosion with multiple high-cardinality tags│
│                                                              │
│  Example: metric with tags [status, claim_id]               │
│    • 10 status codes × 100K claims = 1M time series         │
│    • Each time series stored per retention policy           │
│    • Dashboards time out rendering all series               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Logs (Datadog Logs, Elasticsearch, Splunk)                 │
│                                                              │
│  Storage Model: FULL-TEXT INDEXING                          │
│  - Cost: O(log volume) - bytes ingested                     │
│  - High cardinality in fields handled efficiently           │
│  - Can search by claim_id without creating time series      │
│                                                              │
│  Example: log with fields [status, claim_id]                │
│    • 100K log entries with unique claim_ids = 100K docs     │
│    • Cost based on log volume (bytes), not unique IDs       │
│    • Search "Show me logs for claim_abc123" works instantly │
└─────────────────────────────────────────────────────────────┘
```

### Golden Patterns: Use Right Tool for Cardinality

#### Golden Pattern #1: Low-Cardinality Metrics + High-Cardinality Logs

```ruby
# GOOD: Metrics for aggregation (low cardinality)
StatsD.increment('claim.submitted',
  tags: [
    "form_type:#{claim.form_type}",      # Low: ~50 form types
    "status:#{claim.status}",            # Low: ~5 statuses
    "region:#{claim.region}"             # Low: ~10 regions
  ]
)
# Total cardinality: 50 × 5 × 10 = 2,500 time series (acceptable!)

# GOOD: Logs for specific details (high cardinality)
Rails.logger.info('Claim submitted',
  claim_id: claim.id,              # High cardinality: OK in logs!
  user_id: user.id,                # High cardinality: OK in logs!
  form_type: claim.form_type,
  status: claim.status,
  region: claim.region
)
```

**Why this works:**

- **Metrics**: Answer "How many 526 claims submitted in us-east?" -- Dashboard shows rate over time
- **Logs**: Answer "What happened to claim_abc123?" -- Search by claim_id in logs
- Cardinality stays low, dashboards work, debugging possible

---

#### Golden Pattern #2: Cardinality Decision Tree

```ruby
def track_claim_submission(claim:, user:, status:)
  # Decision: Is cardinality low enough for metrics?

  # Metrics: Low cardinality dimensions only
  StatsD.increment('claim.submitted',
    tags: [
      "form_type:#{claim.form_type}",  # ~50 values
      "status:#{status}"                # ~5 values
    ]
  )

  # Logs: All details including high cardinality
  Rails.logger.info('Claim submitted',
    claim_id: claim.id,           # High cardinality
    user_id: user.id,             # High cardinality
    form_type: claim.form_type,
    status: status,
    timestamp: Time.current
  )
end
```

---

#### Golden Pattern #3: Use Histogram Metrics (Built-in Bucketing)

```ruby
# BAD: Tag with actual duration (infinite cardinality)
StatsD.histogram('request.duration', duration_ms,
  tags: ["duration_ms:#{duration_ms}"]  # Each duration = new series
)

# GOOD: Histogram automatically buckets values
StatsD.histogram('request.duration', duration_ms,
  tags: [
    "endpoint:#{request.path}",     # Low cardinality
    "status:#{response.status}"     # Low cardinality
  ]
)
# StatsD creates percentile buckets (p50, p95, p99) automatically
# No need to tag with actual duration value!

# GOOD: Logs capture exact value
Rails.logger.info('Request completed',
  duration_ms: duration_ms,  # Exact value in logs
  endpoint: request.path,
  status: response.status
)
```

## References

- [Datadog Custom Metrics](https://docs.datadoghq.com/metrics/custom_metrics/)
