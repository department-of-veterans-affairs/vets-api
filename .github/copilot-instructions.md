<!-- These instructions give context for all Copilot chats within vets-api. The instructions you add to this file should be short, self-contained statements that add context or relevant information to supplement users' chat questions. Since vets-api is large, some instructions may not work. See docs: https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot#writing-effective-repository-custom-instructions -->
# Copilot Instructions for vets-api

## Overview
vets-api is a Ruby on Rails API that powers the website VA.gov. It serves as a wrapper around VA data services with utilities and tools that support interaction with those services on behalf of veterans. The main consumer of these APIs is vets-website, the frontend repository that powers VA.gov. Both repositories are in this GitHub organization and work together to deliver services to veterans.


## Architecture & Patterns
- Rails API-only application.
- Follows REST conventions.
- Background Sidekiq jobs in `app/sidekiq` or `modules/<name>/app/sidekiq`
- Uses the rubyconfig/config gem to manage environment-specific settings. Settings need to be added to three files: config/settings.yml, config/settings/test.yml, and config/settings/development.yml and must be in alphabetical order.

## Directory Structure
Some applications in vets-api organize their code into Rails Engines, which we refer to as modules. Those live in `vets-api/modules/`. Other applications are in `vets-api/app`. This is the structure of some directories, for example:
- Controllers: `app/controllers` or `modules/<name>/app/controllers`
- Models: `app/models` or `modules/<name>/app/models`
- Serializers: `app/serializers` or `modules/<name>/app/serializers`
- Services: `app/services` or `modules/<name>/app/services`

## API Practices
- Endpoints are RESTful, versioned under `/v0/`, `/v1/`, etc.
- Use strong parameters for input.
- Return JSON responses.
- Authenticate requests with JWT or OAuth2.
- Standard error responses in JSON format.

## Testing
- **Test Framework**: Use RSpec for tests, located in `spec/` or `modules/<name>/app/spec`.
- **Test Data**: Use FactoryBot for fixtures and test data generation.
- **Feature Toggles**: If using a feature toggle (Flipper), write corresponding tests for both enabled and disabled scenarios.
- **Mocking Flipper**: When testing feature toggles, don't use `Flipper.enable` or `Flipper.disable`. Mock instead:
  ```ruby
  allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)
  ```
- **Test Logging**: To enable logging during tests (disabled by default), set `RAILS_ENABLE_TEST_LOG=true bundle exec rspec path/to/spec.rb`. Test logs write to `log/test.log`.
- **Coverage**: Ensure all new code has comprehensive test coverage including happy path, error cases, and edge cases.
- **External Services**: Mock external service calls using Betamocks or VCR cassettes to ensure reliable, fast tests.

## Utilities
- Faraday: The primary HTTP client for all external API calls. Use Faraday in service objects, and ensure requests are properly instrumented.
- Breakers: Implements the circuit breaker pattern to protect critical external service calls from cascading failures. Use in service configuration.
- Betamocks: Used to mock external HTTP services in development and test environments. Use betamocks to simulate API responses and enable reliable testing without real network requests.
- Custom helpers in `app/lib`.

## Migrations
- Data migrations must be included as a rake task outside of rails database migrations.
- Index updates must always be included in a migration file by itself.
- Index updates must be performed with the concurrently algorithm and outside of the DDL transaction to avoid locking.

## Code Quality
- Runs RuboCop for linting.
- Document complex logic with comments.

## Security
- **PII Protection**: Never log anything that could contain PII or sensitive data, including entire `response_body` objects and `user.icn`.
- **Secrets Management**: Never commit secrets, keys, or credentials to the repository.
- **Data Classification**: Follow VA data classification guidelines when handling veteran data.
- **Authentication**: All endpoints must properly authenticate and authorize requests.
- **Input Validation**: Always validate and sanitize user inputs to prevent injection attacks.
- **Error Messages**: Don't expose sensitive system information in error messages returned to clients.

## VA-Specific Patterns
- **User Context**: Always use the authenticated user context (`@current_user`) for data access and permissions.
- **Veteran Verification**: Verify veteran status before accessing benefits-related data.
- **BGS Integration**: Use BGS (Benefits Gateway Service) for veteran benefits data through established service patterns.
- **MVI Integration**: Use MVI (Master Veteran Index) for veteran identity and demographic data.
- **Form Submissions**: Follow established patterns for form submission processing and validation.
- **Error Handling**: Use standardized error response formats with appropriate HTTP status codes.

## Adding Features
- Add new controllers for new resources following RESTful conventions.
- Write comprehensive tests for all new code including unit, integration, and end-to-end tests.
- Follow established service object patterns for business logic.
- Document any new external service integrations or API changes.

# Tips for Copilot
- Prefer existing patterns and structure.
- Reuse helpers and services when possible.
- Write clear, concise code.
- If asked to create an issue, create it in the department-of-veterans-affairs/va.gov-team repository.

# Code Review Guidelines
When performing a code review, ensure the code follows best practices. Additionally, pay close attention to these specific guidelines:

## Ruby shorthand syntax
- Always enforce Ruby shorthand syntax.
- If a local variable is defined, using shorthand syntax like `{ exclude: }` is valid and correct.
- Do **not** suggest that the key is missing a value.
- Do **not** suggest changing it to `{ exclude: exclude }`.
- Do **not** flag this syntax as an error, incomplete, or unclear.

## Flipper usage in tests
- Avoid enabling or disabling Flipper features in tests.
- **Never** use `Flipper.enable` or `Flipper.disable` in tests.
- Always stub Flipper like this:
  ```ruby
  allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)
  ```
  - Use this exact pattern inline in the example.

## Active Record index migrations
### Isolate index changes
- If a migration includes `add_index` or `remove_index`, it must only include index changes.
- Do **not** combine index changes with other table modifications in the same migration.

### Avoid locking
- A migration that includes `add_index` or `remove_index` must also:
  - Use `algorithm: :concurrently`
  - Include `disable_ddl_transaction!`

This prevents table locking during deployment.
