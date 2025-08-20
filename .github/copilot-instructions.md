<!-- These instructions give context for all Copilot chats within vets-api. The instructions you add to this file should be short, self-contained statements that add context or relevant information to supplement users' chat questions. Since vets-api is large, some instructions may not work. See docs: https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot#writing-effective-repository-custom-instructions -->
# Copilot Instructions for `vets-api`

## Overview

`vets-api` is a Ruby on Rails API that powers VA.gov.
It acts as a wrapper around VA data services, providing utilities and tools that interact with those services on behalf of veterans.

* **Primary consumer**: `vets-website`, the frontend repo that powers VA.gov.
* **Location**: Both repos live in this GitHub organization.

---

## Architecture & Patterns

* Rails API-only application
* REST conventions
* Background jobs run via **Sidekiq** (`app/sidekiq` or `modules/<name>/app/sidekiq`)
* Environment-specific settings managed with `rubyconfig/config`.

  * Add settings to **three files** in alphabetical order:

    * `config/settings.yml`
    * `config/settings/test.yml`
    * `config/settings/development.yml`

---

## Directory Structure

Some apps inside `vets-api` are packaged as Rails Engines ("modules"), located in `vets-api/modules/`. Others live in `vets-api/app/`.

**Common directories:**

* Controllers → `app/controllers` or `modules/<name>/app/controllers`
* Models → `app/models` or `modules/<name>/app/models`
* Serializers → `app/serializers` or `modules/<name>/app/serializers`
* Services → `app/services` or `modules/<name>/app/services`

---

## API Practices

* Endpoints are **RESTful**, versioned under `/v0/`, `/v1/`, etc.
* Use **strong parameters** for input.
* Responses are **JSON** only.
* Authentication via **JWT** or **OAuth2**.
* Standardized **error responses** in JSON format.

---

## Testing

* Framework: **RSpec** (`spec/` or `modules/<name>/spec/`)
* Fixtures: **FactoryBot**
* Feature toggles: **Flipper**

  * Always test both **enabled** and **disabled** states.
  * **Never** call `Flipper.enable` or `Flipper.disable` in tests.
  * Instead, mock like this:

    ```ruby
    allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)
    ```
* Enable logging in tests (off by default):

  ```bash
  RAILS_ENABLE_TEST_LOG=true bundle exec rspec path/to/spec.rb
  ```

  → Logs go to `log/test.log`.

---

## Utilities

* **Faraday**: Primary HTTP client.

  * Use in service objects.
  * Ensure requests are instrumented.
* **Breakers**: Circuit breaker for external API calls.
* **Betamocks**: Mock external HTTP services in development and test.
* **Custom helpers**: Found in `app/lib`.

---

## Migrations

* Data migrations → must be written as **rake tasks**, not Rails migrations.
* **Index updates**:

  * Always in their **own migration file**.
  * Must use `algorithm: :concurrently`.
  * Must include `disable_ddl_transaction!`.
  * Prevents table locking during deploys.

---

## Code Quality

* **RuboCop** for linting.
* Comment **complex logic** for maintainability.

---

## Security

* **Never log** PII or sensitive data (e.g., `response_body`, `user.icn`).
* **Never commit secrets or keys**.
* **Data Classification**: Follow VA data classification guidelines when handling veteran data.
* **Authentication**: All endpoints must properly authenticate and authorize requests.
* **Input Validation**: Always validate and sanitize user inputs to prevent injection attacks.
* **Error Messages**: Don't expose sensitive system information in error messages returned to clients.

---

## VA-Specific Patterns

* **User Context**: Always use the authenticated user context (`@current_user`) for data access and permissions.
* **Veteran Verification**: Verify veteran status before accessing benefits-related data.
* **BGS Integration**: Use BGS (Benefits Gateway Service) for veteran benefits data through established service patterns.
* **MVI Integration**: Use MVI (Master Veteran Index) for veteran identity and demographic data.
* **Form Submissions**: Follow established patterns for form submission processing and validation.
* **Error Handling**: Use standardized error response formats with appropriate HTTP status codes.

---

## Adding Features

* New resources → create new controllers.
* Always write tests for new code.
* Prefer **existing patterns, helpers, and services** over reinventing.
* Follow established service object patterns for business logic.
* Document any new external service integrations or API changes.

---

## Tips for Copilot

* Stick to **established patterns and structure**.
* Reuse existing helpers and services.
* Keep code **clear and concise**.
* If prompted to create an issue, use `department-of-veterans-affairs/va.gov-team` repository.

---

## Code Review Guidelines

In addition to general Rails best practices, reviewers should watch for:

### Ruby shorthand syntax

✅ Use `{ exclude: }` if a local variable exists.
🚫 Do **not** expand to `{ exclude: exclude }`.
🚫 Do **not** flag shorthand as unclear.

### Flipper usage in tests

🚫 Never call `Flipper.enable` or `Flipper.disable`.
✅ Always stub inline with:

```ruby
allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)
```

### ActiveRecord index migrations

* **Isolate index changes** → do not mix with other schema updates.
* Always:

  ```ruby
  disable_ddl_transaction!
  add_index :table, :column, algorithm: :concurrently
  ```