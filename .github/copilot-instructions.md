<!-- These instructions give context for all Copilot chats within vets-api. The instructions you add to this file should be short, self-contained statements that add context or relevant information to supplement users' chat questions. Since vets-api is large, some instructions may not work. See docs: https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot#writing-effective-repository-custom-instructions -->
# Copilot Instructions for vets-api

## Overview
vets-api is a Ruby on Rails API that powers the website VA.gov. It's a wrapper around VA data services with utilities and tools that support interaction with those services on behalf of a veteran The main user of the APIs is vets-website, the frontend repo that powers VA.gov. Both of them are in this GitHub organization.

## Architecture & Patterns
- Rails API-only app.
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
- Use RSpec for tests, located in `spec/` or `modules/<name>/app/spec`.
- Use FactoryBot for fixtures.
- If using a feature toggle, aka Flipper, write corresponding tests for both the Flipper on and Flipper off scenarios.
- When invoking a feature toggle in a test, don't disable or enable it. Mock it instead, using this format for enabling a flipper: `allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)`

## Utilities
- Common gems: Sidekiq, Faraday.
- Custom helpers in `app/lib`.

## Code Quality
- Runs RuboCop for linting.
- Document complex logic with comments.

## Security
- Don't log anything that could contain PII or sensitive data, including an entire response_body.
- Never commit secrets or keys.

## Adding Features
- Add new controllers for new resources.
- Write tests for all new code.

# Tips for Copilot
- Prefer existing patterns and structure.
- Reuse helpers and services when possible.
- Write clear, concise code.
- If asked to create an issue, create it in the department-of-veterans-affairs/va.gov-team repository.
