# Copilot Instructions for `vets-api`

## Repository Context
`vets-api` is a Ruby on Rails API serving veterans via VA.gov. Large codebase (400K+ lines) with modules for appeals, claims, healthcare, and benefits processing.

**Key External Services:** BGS, MVI, Lighthouse APIs
**Architecture:** Rails engines in `modules/`, background jobs via Sidekiq Enterprise

## For Copilot Chat - Development Help

### Quick Commands
- **Test**: `bundle exec rspec spec/` or `make spec`
- **Test with logging**: `RAILS_ENABLE_TEST_LOG=true bundle exec rspec path/to/spec.rb` (logs to `log/test.log`)
- **Lint**: `bundle exec rubocop` (handled by CI, don't suggest fixes)
- **Server**: `foreman start -m all=1`
- **Console**: `bundle exec rails console`
- **DB**: `make db` (setup + migrate)

### Quick Reference
- **Config files**: `modules/[name]/config/` or main `config/`
- **Serializers**: End controllers with `render json: object, serializer: SomeSerializer`
- **Auth**: Most endpoints need `before_action :authenticate_user!`
- **Jobs**: Use `perform_async` for background work, `perform_in` for delayed
- **Flipper in tests**: Never use `Flipper.enable/disable` - always stub with `allow(Flipper).to receive(:enabled?).with(:feature).and_return(true)`

### Common Patterns
- Controllers in `modules/[name]/app/controllers` or `app/controllers`
- Background jobs in `app/sidekiq/` - use for operations >2 seconds
- External service clients in `lib/` with Faraday configuration
- Feature flags via Flipper for gradual rollouts and A/B testing
- Strong parameters required - never use `params` directly
- Error responses use envelope: `{ error: { code, message } }`
- Service objects return `{ data: result, error: nil }` pattern

### Key Dependencies
- PostGIS required for database
- Sidekiq Enterprise (may need license)
- VCR cassettes for external service tests
- Settings: `config/settings.yml` (alphabetical order required)

### VA Service Integration
- **BGS**: Benefits data, often slow/unreliable
- **MVI**: Veteran identity, use ICN for lookups
- **Lighthouse**: Modern REST APIs for claims, health records, veteran verification

## For PR Reviews - Human Judgment Issues

### ⚠️ NO DUPLICATE COMMENTS - Consolidate Similar Issues

### Security & Privacy Concerns
- **PII in logs**: Check for email, SSN, medical data in log statements
- **Hardcoded secrets**: API keys, tokens in source code
- **Missing authentication**: Controllers handling sensitive data without auth checks
- **Mass assignment**: Direct use of params hash without strong parameters

### Business Logic Issues
- **Non-idempotent operations**: Creates without duplicate protection
- **Blocking operations in controllers**: sleep(), File.read, document processing, operations >2 seconds
- **Wrong error response format**: Not using VA.gov standard error envelope
- **Service method contracts**: Returning `{ success: true }` instead of data/error pattern

### VA-Specific Patterns
- **New logging without Flipper**: Logs not wrapped with feature flags
- **External service calls**: Missing error handling, timeouts, retries, or rescue blocks
- **Background job candidates**: File.read operations, PDF/document processing, bulk database updates, .deliver_now emails
- **Wrong identifier usage**: Using User ID instead of ICN for MVI/BGS lookups
- **Form handling**: Complex forms not using form objects for serialization

### Architecture Concerns
- **N+1 queries**: Loading associations in loops without includes
- **Response validation**: Parsing external responses without checks
- **Method complexity**: Methods with many conditional paths or multiple responsibilities
- **Database migrations**: Mixing index changes with other schema modifications; index operations missing `algorithm: :concurrently` and `disable_ddl_transaction!`

## Consolidation Examples

**Good PR Comment:**
```
Security Issues Found:
- Line 23: PII logged (user email)
- Line 45: Hardcoded API key
- Line 67: Missing authentication check
Recommend: Remove PII, move key to env var, add before_action
```

**Bad PR Comments:**
- Separate comment for each security issue
- Flagging things RuboCop catches (style, syntax)
- Repeating same feedback in different words

## Flipper Usage in Tests

Avoid enabling or disabling Flipper features in tests. Instead, use stubs to control feature flag behavior:

**❌ Avoid (modifies global state):**
```ruby
Flipper.enable(:veteran_benefit_processing)
Flipper.disable(:legacy_claims_api)
```

**✅ Correct approach (stubs without side effects):**
```ruby
# Flipper.enable → stub with and_return(true)
allow(Flipper).to receive(:enabled?).with(:veteran_benefit_processing).and_return(true)
# Flipper.disable → stub with and_return(false)  
allow(Flipper).to receive(:enabled?).with(:legacy_claims_api).and_return(false)
```

**Important:** When suggesting stub replacements, preserve the intended behavior:
- `Flipper.enable(:feature)` → stub with `and_return(true)`
- `Flipper.disable(:feature)` → stub with `and_return(false)`

## Context for Responses
- **VA.gov serves millions of veterans** - reliability and security critical
- **External services often fail** - VA systems like BGS/MVI require resilient retry logic
- **PII/PHI protection paramount** - err on side of caution for sensitive data
- **Performance matters** - veterans waiting for benefits decisions
- **Feature flags enable safe rollouts** - wrap new features and risky changes
- **Idempotency critical** - duplicate claims/forms cause veteran issues
- **Error logging sensitive** - avoid logging veteran data in exceptions

## Trust These Guidelines
These instructions focus on issues requiring human judgment that automated tools can't catch. Don't suggest fixes for style/syntax issues - those are handled by CI.