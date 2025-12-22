# Veteran Facing Services

Centralized utilities for veteran-facing applications on VA.gov, providing standardized form notifications and callback handling.

## Overview

**Key Features:**
- Email notifications via VA Notify
- Asynchronous callback processing
- Feature flag integration
- Comprehensive monitoring

## Table of Contents

- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Testing](#testing)

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| VA Notify API | - | Email delivery service |
| Rails | 7.0+ | Parent application |
| Feature flags | - | Flipper integration |

## Configuration

```yaml
# config/settings.yml
vanotify:
  services:
    21p_527ez: &vanotify_services_pension
      api_key: <%= ENV['VANOTIFY_API_KEY'] %>
      email:
        confirmation:
          template_id: form527ez_confirmation_template
          flipper_id: form527ez_confirmation_email
    pensions: *vanotify_services_pension
```

## Usage Examples

### Basic Notification

```ruby
# Send confirmation email
notifier = VeteranFacingServices::NotificationEmail::SavedClaim.new(claim.id)
notifier.deliver(:confirmation)

# Send error notification
notifier.deliver(:error)
```

### Custom Integration

```ruby
class MyFormSubmissionJob
  def perform(saved_claim_id)
    response = external_service.submit(claim)

    notification_type = response.success? ? :confirmation : :error
    VeteranFacingServices::NotificationEmail::SavedClaim
      .new(saved_claim_id)
      .deliver(notification_type)
  end
end
```

### Bulk Notification

```ruby
# All the claims MUST be able to use the same personalization and template
notifier = VeteranFacingServices::NotificationEmail::SavedClaim.new
claims.each do |claim|
  notifier.deliver(:confirmation, claim.id) # claim.id is the saved_claim_id
end
```

## API Reference

### NotificationEmail::SavedClaim

| Method | Parameters | Description |
|--------|------------|-------------|
| `deliver` | `email_type`, `options` | Send email notification |
| `new` | `saved_claim_id`, `service_name` | Initialize notifier |

### NotificationCallback::SavedClaim

| Method | Parameters | Description |
|--------|------------|-------------|
| `process` | `notification_id`, `status`, `metadata` | Handle delivery callbacks |

## Testing

```bash
# Run tests
bundle exec rspec lib/veteran_facing_services/spec/
```

### Feature Flag Stubbing

```ruby
# Stub feature flags in tests
allow(Flipper).to receive(:enabled?)
  .with(:form527ez_confirmation_email)
  .and_return(true)
```

Provides standardized email notifications and callback handling for veteran form submissions across VA.gov services.
