# Copilot Instructions for `vets-api`

## Repository Context
`vets-api` is a Ruby on Rails API serving veterans via VA.gov. Large codebase (400K+ lines) with modules for appeals, claims, healthcare, and benefits processing.

**Key External Services:** BGS, MVI, Lighthouse APIs, EVSS (being deprecated)
**Architecture:** Rails engines in `modules/`, background jobs via Sidekiq Enterprise

## For Copilot Chat - Development Help

### Quick Commands
- **Test**: `bundle exec rspec spec/` or `make spec`
- **Lint**: `bundle exec rubocop` (handled by CI, don't suggest fixes)
- **Server**: `foreman start -m all=1`
- **Console**: `bundle exec rails console`
- **DB**: `make db` (setup + migrate)

### Quick Reference
- **Config files**: `modules/[name]/config/` or main `config/`
- **Serializers**: End controllers with `render json: object, serializer: SomeSerializer`
- **Auth**: Most endpoints need `before_action :authenticate_user!`
- **Jobs**: Use `perform_async` for background work, `perform_in` for delayed

### Common Patterns
- Controllers in `modules/[name]/app/controllers` or `app/controllers`
- Background jobs in `app/sidekiq/` - use for operations >2 seconds
- External service clients in `lib/` with Faraday + timeouts + retries
- Feature flags via Flipper - always wrap debugging logs
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
- **Lighthouse**: Preferred over legacy EVSS
- **EVSS**: Being deprecated, migrate to Lighthouse

## For PR Reviews - Human Judgment Issues

### ⚠️ NO DUPLICATE COMMENTS - Consolidate Similar Issues

### Security & Privacy Concerns
- **PII in logs**: Check for email, SSN, medical data in log statements
- **Hardcoded secrets**: API keys, tokens in source code
- **Missing authentication**: Controllers handling sensitive data without auth checks
- **Mass assignment**: Direct use of params hash without strong parameters

### Business Logic Issues  
- **Non-idempotent operations**: Creates without duplicate protection
- **Blocking operations in controllers**: sleep(), long external calls, file processing
- **Wrong error response format**: Not using VA.gov standard error envelope
- **Service method contracts**: Returning `{ success: true }` instead of data/error pattern

### VA-Specific Patterns
- **New logging without Flipper**: Suggest wrapping debug logs with feature flags
- **External service calls**: Missing timeouts, retries, or error handling context
- **Background job candidates**: Synchronous operations that should be async
- **Feature flag testing**: Using .enable/.disable instead of stubbing in tests
- **ICN vs User ID**: Use ICN for veteran lookups with MVI/BGS
- **Form serialization**: Use form objects for complex form submissions
- **Lighthouse migration**: Flag EVSS usage, suggest Lighthouse alternatives

### Architecture Concerns
- **N+1 queries**: Loading associations in loops without includes
- **Response validation**: Parsing external responses without checks
- **Method complexity**: Methods handling multiple concerns or very long
- **Database migrations**: Mixing index changes with other schema modifications

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

## Context for Responses
- **VA.gov serves millions of veterans** - reliability and security critical
- **External services often fail** - assume timeouts and retries needed  
- **PII/PHI protection paramount** - err on side of caution for sensitive data
- **Performance matters** - veterans waiting for benefits decisions
- **Feature flags enable safe rollouts** - wrap risky or debug code
- **Idempotency critical** - duplicate claims/forms cause veteran issues
- **Error logging sensitive** - avoid logging veteran data in exceptions

## Trust These Guidelines
These instructions focus on issues requiring human judgment that automated tools can't catch. Don't suggest fixes for style/syntax issues - those are handled by CI.