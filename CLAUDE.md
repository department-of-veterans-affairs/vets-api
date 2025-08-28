# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Vets API is a Ruby on Rails API providing common services for applications on VA.gov (formerly vets.gov). It serves millions of veterans with benefits, healthcare, appeals, and claim processing functionality.

**Core Technologies:**
- Ruby ~3.3.6
- Rails ~7.2.2  
- PostgreSQL 15.x with PostGIS 3
- Redis 6.2.x
- Sidekiq (Enterprise for production features)

**Key External Services:**
- BGS (Benefits Gateway Services) - benefits data
- MVI (Master Veteran Index) - veteran identity
- Lighthouse APIs - modern REST APIs for claims, health records
- VA Profile - contact information

## Project Architecture

**Modular Structure:**
- Main Rails app in `app/` directory
- Modules in `modules/` directory (Rails engines for specific features)
- Each module contains: appeals_api, claims_api, mobile, my_health, etc.
- Shared concerns and base classes in main app

**Key Directories:**
- `app/controllers/` - Base controllers and shared functionality
- `app/models/` - Core domain models and shared entities  
- `app/serializers/` - JSON API serializers for responses
- `app/services/` - Business logic services
- `app/sidekiq/` - Background jobs
- `modules/*/` - Feature-specific Rails engines
- `lib/` - Utilities and external service integrations
- `config/` - Application configuration and settings

## Common Development Commands

**Setup and Dependencies:**
```bash
# Install dependencies
bundle install

# Database setup and migration
make db

# Alternative database commands
bundle exec rails db:create db:migrate
```

**Running the Application:**
```bash
# Start all services with Foreman
foreman start -m all=1

# Rails console
bundle exec rails console
```

**Testing:**
```bash
# Run all tests
bundle exec rspec spec/

# Run specific test file
bundle exec rspec path/to/spec_file.rb

# Run tests with logging (logs to log/test.log)
RAILS_ENABLE_TEST_LOG=true bundle exec rspec path/to/spec.rb

# Alternative test command
make spec
```

**Code Quality:**
```bash
# Run RuboCop linter
bundle exec rubocop

# Run Brakeman security scanner
bundle exec brakeman
```

## Development Patterns and Standards

**Authentication and Authorization:**
- Most endpoints require `before_action :authenticate_user!`
- Use ICN (Integration Control Number) for veteran identification with external services
- Policy classes in `app/policies/` for authorization logic

**API Responses:**
- Use serializers: `render json: object, serializer: SomeSerializer`
- Error responses use envelope format: `{ error: { code, message } }`
- Service objects return `{ data: result, error: nil }` pattern

**Background Jobs:**
- Use Sidekiq for operations taking >2 seconds
- Jobs in `app/sidekiq/` directory
- `perform_async` for immediate background work
- `perform_in` for delayed execution

**Feature Flags:**
- Flipper for gradual rollouts and A/B testing
- In tests, stub instead of enable/disable: `allow(Flipper).to receive(:enabled?).with(:feature).and_return(true)`

**External Service Integration:**
- Service clients in `lib/` with Faraday configuration  
- Always include error handling, timeouts, retries
- Use VCR cassettes for testing external service calls
- BGS and MVI services can be slow/unreliable - implement resilient retry logic

**Security Considerations:**
- Never log PII (email, SSN, medical data)
- Use strong parameters - never use `params` directly
- Store sensitive config in environment variables
- Implement idempotent operations to prevent duplicate submissions

**Database:**
- PostGIS required for geospatial functionality
- Use `algorithm: :concurrently` for index operations in migrations
- Add `disable_ddl_transaction!` for concurrent index operations

## Configuration

**Settings:**
- Main configuration in `config/settings.yml` (maintain alphabetical order)
- Environment-specific overrides in `config/settings/[environment].yml`
- Local development customization in `config/settings.local.yml`

**Important Config Files:**
- `config/routes.rb` - API routing
- `config/database.yml` - Database configuration
- `config/sidekiq.yml` - Background job configuration
- `Gemfile` - Ruby dependencies

## Testing Guidelines

**Test Structure:**
- RSpec tests in `spec/` directory
- Module-specific tests in `modules/*/spec/`
- Use VCR for external service mocking
- Factory Bot for test data creation

**Best Practices:**
- Stub Flipper features instead of enabling/disabling
- Test error conditions and edge cases
- Mock external service calls
- Use `rails_helper.rb` for Rails-specific tests
- Use `spec_helper.rb` for unit tests

## Module-Specific Notes

**Appeals API (`modules/appeals_api/`):**
- Handles Notice of Disagreements and appeals processing
- Integrates with Caseflow and decision review services

**Claims API (`modules/claims_api/`):** 
- Disability compensation claims submission and status
- Power of Attorney management
- Intent to File processing

**Mobile (`modules/mobile/`):**
- Mobile-specific API endpoints
- Veteran-facing mobile application support

**My Health (`modules/my_health/`):**
- Healthcare records and appointments
- Prescription management
- Secure messaging with healthcare providers

## External Service Integration Notes

**BGS (Benefits Gateway Services):**
- Legacy SOAP-based service for benefits data
- Can be slow and unreliable - implement robust retry logic
- Use veteran ICN for lookups

**MVI (Master Veteran Index):**
- Veteran identity and correlation service
- Critical for linking veteran records across systems
- Returns ICN used by other services

**Lighthouse APIs:**
- Modern REST APIs replacing legacy services
- More reliable than BGS for supported operations
- OAuth 2.0 authentication