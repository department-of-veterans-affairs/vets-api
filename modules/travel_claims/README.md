# Travel Claims Standalone Module

A Rails Engine for standalone travel reimbursement claims submission.

## Overview

This module provides a standalone application for veterans to submit travel reimbursement claims using low authentication (last name + date of birth) without going through the check-in flow.

## Architecture

### Shared Services

This module uses shared domain services from `/lib/travel_claim/`:
- `TravelClaim::ClaimSubmissionService` - Handles claim submission workflow
- `TravelClaim::TravelPayClient` - Communicates with Travel Pay API
- `TravelClaim::RedisClient` - Manages Redis operations

### Module-Specific Components

- **Controllers**: Handle HTTP requests and responses
- **Models**: Thin wrappers around shared check-in models (e.g., session management)
- **Constants**: Module-specific template IDs and metrics

## Key Differences from Check-In

| Feature | Check-In | Travel Claims Standalone |
|---------|----------|-------------------------|
| Entry Point | Check-in flow | Direct travel claims |
| Authentication | LoROTA (reused) | LoROTA (reused) |
| Cookie Name | `cie_session` | `travel_claims_session` |
| Routes | `/check_in/*` | `/travel_claims/*` |
| Constants | `CheckIn::Constants` | `TravelClaims::Constants` |
| Metrics Prefix | `check_in` | `travel_claims` |

## API Endpoints

### Sessions (Authentication)
- `POST /travel_claims/v0/sessions` - Create session (authenticate)
- `GET /travel_claims/v0/sessions/:id` - Check session status

### Claims
- `POST /travel_claims/v0/claims` - Submit travel claim

## Feature Flags

- `travel_claims_standalone_enabled` - Master feature flag for standalone app

## Configuration

### Required Settings

Template IDs must be configured in `config/settings.yml`:

```yaml
vanotify:
  services:
    travel_claims:
      template_id:
        claim_submission_success_text: 'template-id'
        claim_submission_duplicate_text: 'template-id'
        claim_submission_error_text: 'template-id'
```

## Development

### Running Tests

```bash
bundle exec rspec modules/travel_claims
```

### Rails Console

```bash
bundle exec rails console
TravelClaims::Engine  # Verify engine loads
```

## Related Documentation

- [Check-In Module](../check_in/README.md)
- [Shared Travel Claim Services](../../lib/travel_claim/README.md)
- [Implementation Tickets](../../travel-claims-implementation-tickets.md)


