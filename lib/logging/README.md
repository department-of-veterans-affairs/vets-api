# Logging

Centralized logging utilities for vets-api that provide standardized monitoring, error tracking, and metrics collection across all services.

## Overview

The logging library provides a unified interface for:
- **Structured logging** with Rails.logger
- **Metrics collection** with StatsD
- **Error tracking** with consistent formatting
- **PII protection** through parameter filtering

## Components

### Logging::Monitor

Generic monitoring class for tracking service operations with both logging and metrics.

```ruby
# Initialize monitor for your service
monitor = Logging::Monitor.new('my-service')

# Track successful operations
monitor.track_request(:info, 'Operation completed', 'my_service.success')

# Track errors with context
monitor.track_request(:error, 'API call failed', 'my_service.error',
                     exception: error.message,
                     tags: ['endpoint:claims'])
```

### Other Components

- [`Logging::Helper::DataScrubber`](lib/logging/helper/data_scrubber.rb) - PII removal utilities
- [`Logging::ThirdPartyTransaction`](lib/logging/third_party_transaction.rb) - External service call logging
- [`Logging::Include::Controller`](lib/logging/include/controller.rb) - Controller-specific monitoring

## Usage Patterns

### Service Integration

```ruby
class MyService
  def initialize
    @monitor = Logging::Monitor.new('my-service')
  end

  def perform_operation
    @monitor.track_request(:info, 'Starting operation', 'my_service.start')

    result = do_work

    @monitor.track_request(:info, 'Operation successful', 'my_service.success')
    result
  rescue StandardError => e
    @monitor.track_request(:error, "Operation failed: #{e.message}",
                          'my_service.error', error: e.message)
    raise
  end
end
```

## Features

### Automatic PII Filtering

All context parameters are automatically filtered to prevent PII leakage:

```ruby
monitor.track_request(:info, 'User action', 'user.login',
                     email: 'user@example.com',  # Will be filtered
                     ssn: '123-45-6789')         # Will be filtered
```

### StatsD Integration

Every `track_request` call automatically:
- Increments the specified metric in StatsD
- Adds service and function tags
- Includes any custom tags provided

### Structured Logging

Log entries include consistent metadata:
- Service name
- Function name
- File and line number
- Filtered context parameters
- StatsD metric name

## Best Practices

### Service Naming

Use consistent, descriptive service names:
- `claims-evidence-api` - for [`ClaimsEvidenceApi::Monitor`](modules/claims_evidence_api/lib/claims_evidence_api/monitor.rb)
- `decision-reviews` - for decision review operations
- `benefits-intake` - for document uploads

### Error Levels

Choose appropriate log levels:
- `:info` - Normal operations, successful completions
- `:warn` - Unexpected but recoverable conditions
- `:error` - Errors that affect operation but allow continuation
- `:fatal` - Critical errors that may cause service failure

### Metrics Naming

Follow DataDog conventions:
- Use dots to separate namespaces: `service.operation.result`
- Include relevant tags for filtering
- Keep metric names descriptive but concise

## Integration Examples

The logging utilities are used throughout vets-api:

- **Claims Evidence API**: [`ClaimsEvidenceApi::Monitor`](modules/claims_evidence_api/lib/claims_evidence_api/monitor.rb)
- **Decision Reviews**: [`DecisionReviews::V1::LoggingUtils`](modules/decision_reviews/lib/decision_reviews/v1/logging_utils.rb)
- **Claims API**: [`ClaimsApi::Logger`](modules/claims_api/lib/claims_api/claim_logger.rb)
- **Zero Silent Failures**: [`ZeroSilentFailures::Monitor`](lib/zero_silent_failures/monitor.rb)

This centralized approach ensures consistent logging across all VA.gov services while protecting veteran PII and providing actionable metrics for monitoring and debugging.
