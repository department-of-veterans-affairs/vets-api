# Copilot Instructions for `vets-api`

## Repository Context
`vets-api` is a Ruby on Rails API serving veterans via VA.gov. Large codebase (400K+ lines) with modules for appeals, claims, healthcare, and benefits processing.

**Default Branch:** `master` - All code reviews and comparisons should be against the `master` branch
**Key External Services:** BGS, MVI, Lighthouse APIs
**Architecture:** Rails engines in `modules/`, background jobs via Sidekiq Enterprise

## For Copilot Chat - Development Help

### Quick Commands
- **Test**: `bundle exec rspec spec/` or `make spec`
- **Test with logging**: `RAILS_ENABLE_TEST_LOG=true bundle exec rspec path/to/spec.rb` (logs to `log/test.log`)
- **Test parallel**: `make spec_parallel` (faster for full test suite)
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

### Module Structure (Rails Engines)
- Each module in `modules/` is a Rails engine with its own namespace
- Module controllers inherit from `ApplicationController` or their module's base controller
- Module routes defined in `modules/[name]/config/routes.rb`
- Module configs in `modules/[name]/config/`
- Shared code belongs in main `app/` or `lib/` directories
- Module-specific serializers in `modules/[name]/app/serializers/[namespace]/`

### Key Dependencies
- PostGIS required for database
- Sidekiq Enterprise (may need license)
- VCR cassettes for external service tests
- Settings: `config/settings.yml` (alphabetical order required)

### Gemfile and Dependency Management
- **DO NOT commit Gemfile or Gemfile.lock changes** unless they are necessary for the feature/fix you are implementing
- **DO NOT commit local Gemfile modifications** that remove the `sidekiq-ent` and `sidekiq-pro` gems (these may be removed locally if you don't have a Sidekiq Enterprise license, but should never be committed)
- Gemfile.lock changes from running `bundle install` to get your local dev environment working should NOT be committed
- Only commit Gemfile changes when adding, removing, or updating gems as part of your feature work
- Ruby and gem versions are defined in `Gemfile` and locked in `Gemfile.lock`
- If you need a newer version of a gem, submit a draft PR with just the gem updated and passing tests

### VA Service Integration
- **BGS**: Benefits data, often slow/unreliable
- **MVI**: Veteran identity, use ICN for lookups
- **Lighthouse**: Modern REST APIs for claims, health records, veteran verification

## For PR Reviews - Human Judgment Issues

**Note:** This repository uses `master` as the default branch. All PR reviews should compare changes against the `master` branch.

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

### Anti-Patterns
- **New logging without Flipper**: Logs not wrapped with feature flags
- **External service calls**: Missing error handling, timeouts, retries, or rescue blocks
- **Background job candidates**: File.read operations, PDF/document processing, bulk database updates, .deliver_now emails
- **Wrong identifier usage**: Using User ID instead of ICN for MVI/BGS lookups
- **Form handling**: Complex forms not using form objects for serialization
- **Unnecessary Gemfile changes**: Committing Gemfile/Gemfile.lock changes that are not required for the feature (e.g., local dev environment setup changes, removal of sidekiq-ent/sidekiq-pro gems)

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

**⚠️ IMPORTANT: DO NOT suggest changes to Flipper stubs that already follow the correct pattern below.**

Avoid enabling or disabling Flipper features in tests. Instead, use stubs to control feature flag behavior:

**❌ ONLY flag these patterns (modifies global state):**
```ruby
Flipper.enable(:veteran_benefit_processing)
Flipper.disable(:legacy_claims_api)
```

**✅ This is the CORRECT pattern - DO NOT suggest changes to this:**
```ruby
# This is the correct way to stub Flipper in tests
allow(Flipper).to receive(:enabled?).with(:veteran_benefit_processing).and_return(true)
allow(Flipper).to receive(:enabled?).with(:legacy_claims_api).and_return(false)
```

**Critical for PR Reviews:**
- If you see `allow(Flipper).to receive(:enabled?).with(:feature).and_return(true/false)` - this is CORRECT, do not comment
- ONLY suggest changes when you see actual `Flipper.enable()` or `Flipper.disable()` calls
- Never suggest replacing correct stubs with identical stubs

## Testing Patterns

### Test Organization
- **Request specs**: In `spec/requests/` for API endpoint testing
- **Unit specs**: In `spec/models/`, `spec/services/`, etc. for isolated component testing
- **Module specs**: In `modules/[name]/spec/` for module-specific functionality
- **Factories**: Use FactoryBot factories in `spec/factories/` or `modules/[name]/spec/factories/`
- **VCR cassettes**: For external API responses in `spec/fixtures/` or module equivalent

### Test Conventions
- Use `let` for test data setup, avoid instance variables
- Stub external services with VCR or custom stubs
- Test both success and failure scenarios for external service calls
- Include edge cases: empty responses, timeouts, malformed data
- Use descriptive test names that explain the expected behavior

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

## Tool Calling Efficiency
You have the capability to call multiple tools in a single response. For maximum efficiency, whenever you need to perform multiple independent operations, ALWAYS call tools simultaneously whenever the actions can be done in parallel rather than sequentially.

Especially when exploring repository, searching, reading files, viewing directories, validating changes, reporting progress or replying to comments. For example you can read 3 different files in parallel, or report progress and edit different files in parallel. Always report progress in parallel with other tool calls that follow it as it does not depend on the result of those calls.

However, if some tool calls depend on previous calls to inform dependent values like the parameters, do NOT call these tools in parallel and instead call them sequentially.

---

## Platform Documentation (Auto-synced from Confluence)

**Last synced**: 2025-11-07 21:00:34 UTC

The following standards are automatically synced from Backend Developer Documentation in Confluence.

### Best Practices for Writing Pull Requests

Last Updated: July 1, 2025

As you develop new applications and features on [VA.gov](http://va.gov/) you will need to have your code reviewed by Platform engineers. This helps ensure quality and stable work is being produced. This page provides best practices for writing pull requests.

## 1. Plan accordingly

* Ensure that you have planned enough time to meet your deadlines and have accounted for the review time in that timeline (maximum of 3 business days to review a PR).

*Note: We cannot guarantee a PR can be pushed through due to lack of planning.*

## 2. Review applicable documentation

We recommend reading through the following documentation prior to opening a PR:

* Understand [how we use GitHub code owners](https://depo-platform-documentation.scrollhelp.site/developer-docs/how-we-use-github-code-owners).

## 3. Make PRs clear

* Give your PR a title that sums up what's changed.
* Describe the changes so reviewers know what they're looking at.
* Link to any related GitHub issues for context. Or paste screenshots from Jira (Platform doesn’t have access to Jira).
* Clearly outline how to test the change (not just locally) and what the expected results are.

## 4. Break down tasks

* Don't bite off more than you can chew. Break big tasks into smaller, more manageable ones.
* For example, when building a new page, tackle it step by step:

  + Set up the page structure.
  + Add in each component one by one.
* This way, each part gets proper attention without overwhelming anyone.

## 5. Mitigate PR size

* Keep your PRs compact, aiming for less than 500 lines of code.
* It makes reviews quicker and easier for everyone involved.
* If your PR is too big, offer extra help to reviewers:

  + Point out important changes.
  + Be available for a quick chat to explain things.
  + Write detailed descriptions to guide reviewers.

## 6. Branch smart

* Start a new branch for each feature you're working on.
* Create a PR for each sub-branch, using the main branch as the base.
* It keeps things organized and makes merging smoother.

## 7. Stay on track

* Stick to the task at hand. Focus on solving the issues in your ticket.
* It makes reviews smoother and saves time for everyone.

## 8. Note if a PR is urgent (only if actually urgent)

* All Pull Requests submitted to the Platform Support Team via the /support command in the #vfs-platform-support channel are reviewed within 3 business days of the PR being ready for review (tests passing, etc.).
* If your PR review needs to be reviewed before that time period occurs, please note that your PR is *Critical*

  + Examples of *critical issues* include:

    - A bug that’s preventing a significant number of Veterans from accessing a feature
    - A bug creating a non-trivial deviation from expected functionality
    - A 508/accessibility failure of severity level **0** (*Showstopper*) or **1** (*Critical*) ([severity rubric](https://depo-platform-documentation.scrollhelp.site/developer-docs/accessibility-defect-severity-rubric))
    - A PR needs to be merged to unblock other developers.

      * Example: A form schema update in another repo was merged, but the corresponding code changes need to be merged as well, otherwise there will be test failures in CI for other devs.

    Examples of *non-critical issues* include:

    - Incorrect text or visual formatting that does not impede the feature from working
    - Any code for features not yet released to Veterans
    - Just wanting to get code out sooner

    When in doubt on whether an issue is *critical* enough for out-of-band deployment, OCTO-DE leadership for the Platform will decide.

*Note: If you have a PR that is dependent upon a tight turnaround time or a specific deadline, we recommend submitting your PR as soon as it is ready to ensure that you receive an approval in time to meet said deadline.*

## 9. Help your reviewers

The Platform Support Team looks for the following standards when reviewing PRs. Meeting these standards could ensure a quicker review:

* Correctness: Does the code correctly implement the described feature?
* Code quality: Is the code readable? Is the code language-idiomatic?
* Visual changes: are screenshots of the change(s) included?

## 10. Mind your style

* Run your code through a linter before submitting a PR.
* If you ignore a linting recommendation, explain why in the PR comments.
* Fix any unrelated issues separately.

## 11. Use drafts wisely

* If your PR isn't ready for review, mark it as a draft.
* This stops premature notifications and gives you time to polish things up.

## 12. Meet PR requirements before setting to ready for review

A Pull Request will not be added to the review queue until all criteria below is met:

1. A team member is required to review and approve your pull request.
2. All *required* checks need to pass.

   1. If you are having trouble passing your checks, Platform Support can help.
3. The Platform Support Team cannot see Jira tickets.

   1. You need to put your Jira information in the PR body in the form of a screenshot, by copying and pasting the info, or by making a GitHub issue to link.
4. For Vets API PRs, see this page for extra tips on setting your PR up for success.

*Note: If you have not met these requirements, there may be a delay in the review of your PR.*

## 13. Wait 3 business days before sending a ticket asking for an update

Our engineers review queues multiple times a day, and all reviews are started within 3 business days. Submitting a ticket before this period may delay PR reviews. If it's been longer than 3 business days, please reach out to the Platform Support Team for assistance.

### Best practices

true

Frontend development best practices.

We have launched a number of different single-page React/Redux apps on VA.gov, in addition to building digital forms using a [form-builder library](https://github.com/mozilla-services/react-jsonschema-form) that reuses the same code to run multiple React apps for different forms. This document is an attempt to begin collecting best practices that the team has and continues to lean toward when architecting and developing front-end applications.

## React/Redux guidelines

### Components vs. containers

A common React/Redux application architecture is to divide your React components into two types: regular components and container components. These are also sometimes referred to as a dumb and smart components. Container components connect to the Redux store using the `react-redux` library's `connect` function and map a specific part of the state object to the props of a React component. Regular components are just plain React components; they take in props and they can have internal state (though we generally avoid this; see below).

In general, we try to use regular components whenever possible and only a few container components. The reason for this is because tying a component to the Redux store couples it to a particular slice of the state of your application, as well as coupling it to a particular way of organizing your state. So refactoring a lot of container components can be difficult. Debugging can also be difficult with a lot of container components, because they interrupt the usual flow of data down through components. Instead of all data being passed down via props from a single component at the top of the component tree, intermediate components might pull in different parts of the Redux state and pass down that data as props to other components, creating a mix of data combined from different connections to the Redux state.

There are benefits to using container components, though. It can be painful to pass lots of props all the way down to the leaf components in a component tree and container components allow you to "reset" and grab specific data from the store without all that wiring. They can also improve performance, because passing props down from the root of the component tree means that all intermediate components will re-render whenever data changes. Container components can send data down to their children without all the parents of the container component re-rendering.

On VA.gov, we normally use a single container component per page (or independent widget, like login), and only use other container components if there's a compelling reason for doing so. Our apps have a `containers` folder and a `components` folder that we divide components between.

### Using setState in React components

We also generally avoid `setState` inside regular components. This isn't because `setState` is bad, necessarily, but because it can be hard to track down data changes due to `setState` when you're expecting all changes to go through the single Redux store. It can also be tricky to keep that state in sync with the data from the Redux store passed in as props. So, when we do use `setState`, it's typically for ephemeral UI state, or state that would be more difficult to follow if it were put in the store and passed down through props.

note

Keep in mind that these are general conventions, not iron-clad rules, and we should revisit them as we gain more experience using React and Redux.

Keep in mind that these are general conventions, not iron-clad rules, and we should revisit them as we gain more experience using React and Redux.

## Additional best practices documentation

1simple

### Best practices for using Cypress

End-to-end testing on VA.gov is accomplished using a front-end testing framework called Cypress. Cypress tests run in the browser and programmatically simulate a real user using a web application, or product. These tests are used to verify that the product works as expected across different browsers and viewport dimensions.

The following documentation details Cypress best practices.

true

A guide to Cypress best practices for end-to-end testing on VA.gov.

## Running tests

Cypress supports Chrome, Edge, Firefox, and a few [others](https://docs.cypress.io/guides/guides/launching-browsers.html#Browsers). You can run tests in headless mode or via the test runner. Continuous Integration and builds run Cypress tests in Chrome.

### Headless mode

To run headless tests, run `yarn cy:run`.

By default, `yarn cy:run` runs Cypress tests headlessly in an Electron browser. You may specify another browser, and if you would like to run headless tests in another browser, you will have to explicitly include the `--headless` flag. We are currently running our tests in Chrome using the setup below:

yarn cy:run --headless --browser chrome

You may experience some performance issues where particular long-running tests (such as an exhaustive test of a form) may take an extremely long time (unless your setup is optimized for them, as in the case of our CI, which tests the production build and also has the specs to cancel out the performance burden).

For this reason, for local development, it might be better to run specific specs, even more so in the test runner.

### Test runner

To run tests in the Cypress [test runner](https://docs.cypress.io/guides/core-concepts/test-runner.html#Overview), run `yarn cy:open`.

There is a dropdown menu in the top right of the test runner that allows you to select a browser in which to run your tests. In our experience, Firefox has yielded the fastest test runs when testing locally, although it is currently a beta feature. The tests in CI will run in the default browser, which is Electron.

The test runner provides the ability to pause tests, and [time travel](https://docs.cypress.io/guides/core-concepts/cypress-app#Time-traveling), which allows you to see snapshots of your tests.

With the test runner, you can use Cypress's "[Selector Playground](https://docs.cypress.io/guides/core-concepts/cypress-app#Time-traveling)". This allows you to click on elements in the DOM and copy that element's selector to use in your test. Selecting elements by CSS attributes is discouraged in favor of selecting by a test ID, which is in turn considered a fallback if selecting by other attributes (label text, role, etc.) is not feasible. The Selector Playground follows this best practice and automatically attempts to determine the selector by looking at `data-cy`, `data-test`, and `data-testid` before falling back to a CSS selector.

You may find it useful to append certain [options](https://docs.cypress.io/guides/guides/command-line#Options) to the commands above.

## Things to note

### Automatic waiting

Cypress automatically waits for commands to execute before moving on to the next one. This eliminates the need to use the timeout constants in `platform/testing/e2e/timeouts.js`.

Cypress queues its commands instead of running them synchronously, so doing something like [this](https://docs.cypress.io/guides/references/best-practices.html#Assigning-Return-Values) will not work.

### Third-party plugins

Cypress has many third-party [plugins](https://docs.cypress.io/plugins/) available. If you find yourself needing to do something that isn't natively supported, there may be a plugin for it.

## Cypress Form Tester

Source file: <https://github.com/department-of-veterans-affairs/vets-website/blob/main/src/platform/testing/e2e/cypress/support/form-tester/index.js>

The form tester is a utility that automates Cypress end-to-end (E2E) tests on forms contained within applications on VA.gov. The form tester automatically fills out forms using data from JSON files that represent the body of the API request that's sent upon submitting the form.

Use the form tester to test forms on VA.gov applications.

Please see the Form tester utility for more information.

## Cypress custom commands

Custom Cypress commands abstract away common behaviors that are required across VA.gov applications. The following custom commands are available:

* Mock Users/Data
* Accessibility
* Viewport Testing
* Keyboard Testing
* Other Helper Functions

## Cypress testing library selectors

In addition to Cypress’ [comprehensive API](https://docs.cypress.io/api/api/table-of-contents.html) for interacting with elements, the VSP platform utilizes the [Cypress Testing Library](https://testing-library.com/docs/cypress-testing-library/intro/) which allows us to test UI components in a user-centric way. This library gives us access to all of [DOM Testing Library's](https://testing-library.com/docs/dom-testing-library/api-queries/) `findBy*`, `findAllBy*`, `queryBy,` and `queryAllBy` commands off the global `cy` object.

Please note: The Cypress Testing Library queries should be preferred over Cypress’ `cy.get()` or `cy.contains()` for selecting elements.

The following is a list of queries provided by the Cypress Testing Library, [in the order in which we recommend them](https://testing-library.com/docs/guide-which-query/)\* (e.g., prefer `findByLabelText` over `findByRole` over `findByTestId`).

| `find` | `findAll` |
| --- | --- |
| `findByLabelText` | `findByPlaceholderText` |
| `findByText` | `findByAltText` |
| `findByTitle` | `findByDisplayValue` |
| `findByRole` | `findByTestId` |
| `findAllByLabelText` | `findAllByPlaceholderText` |
| `findAllByText` | `findAllByAltText` |
| `findAllByTitle` | `findAllByDisplayValue` |
| `findAllByRole` | `findAllByTestId` |

**\* Note:** the `get_`queries are not supported because for reasonable Cypress tests you need retry-ability and `find\*` queries already support that.

The `TestId` queries look at the `data-testid` attributes of DOM elements (see the next section).

## data-testid Attribute

While the official Cypress documentation recommends the `data-cy` attribute, we recommend that you use the `data-testid` attribute because it is test-framework agnostic.

Add the `data-testid` attribute to your markup when your test would otherwise need to reference elements by CSS attributes as the last resort. As much as possible, prefer writing selectors for `data-testid` attributes over CSS selectors (ids and classes).

The goal is to write tests that [resemble how your users use your app](https://kentcdodds.com/blog/making-your-ui-tests-resilient-to-change), hence the order of precedence for selecting elements.

## Page Objects

JavaScript objects can be used to create [page objects](https://www.selenium.dev/documentation/guidelines/page_object_models/) in Cypress tests. In test scenarios where multiple pages are interacted with and where the same test actions are performed multiple times, we recommend using page objects to make tests more readable, reduce duplication of code, and reduce total lines of code. Examples of page object usage can be found in the [Claims Status tests](https://github.com/department-of-veterans-affairs/vets-website/tree/main/src/applications/claims-status/tests/e2e) and the [Address Validation tests](https://github.com/department-of-veterans-affairs/vets-website/tree/main/src/applications/personalization/profile/tests/e2e/address-validation).

Here’s an example of a [page object](https://github.com/department-of-veterans-affairs/vets-website/blob/main/src/applications/personalization/profile/tests/e2e/address-validation/page-objects/AddressPage.js) that contains a reusable block of code:

import featureTogglesEnabled from '../fixtures/toggle-covid-feature.json';
class AddressPage {
loadPage = config => {
setUp(config);
};
fillAddressForm = fields => {
fields.country && cy.findByLabelText(/Country/i).select(fields.country);
fields.military &&
cy
.findByRole('checkbox', {
name: /I live on a.\*military base/i,
})
.check();
fields.military && cy.get('#root\_city').select('FPO');
if (fields.address) {
cy.findByLabelText(/^street address \(/i).as('address1');
cy.get('@address1').click();
cy.get('@address1').clear();
cy.findByLabelText(/^street address \(/i).type(fields.address);
}
...

These can then be used to make a short, concise, and readable test as follows:

import AddressPage from './page-objects/AddressPage';
describe('Personal and contact information', () => {
context('when entering info on line two', () => {
it('show show the address validation screen', () => {
const formFields = {
address: '36320 Coronado Dr',
address2: 'care of Care Taker',
city: 'Fremont',
state: 'CA',
zipCode: '94536',
};
const addressPage = new AddressPage();
addressPage.loadPage('valid-address');
addressPage.fillAddressForm(formFields);
addressPage.saveForm();
addressPage.confirmAddress(formFields);
cy.injectAxeThenAxeCheck();
});
});
});

### Best Practices

Last Updated:

This page contains links to documents that will help you better understand best practices when working with the backend. These linked documents contain information and guidelines that will assist you in improving [VA.gov](http://va.gov/).

### Backend developer documentation

Last Updated:

## Introduction

[VA.gov](http://VA.gov)’s frontend repository (vets-website) uses vets-api as a service layer for all features. To expose new data or systems to vets-website, engineers should create an integration in vets-api. If you would like to expose an existing service's API, without an associated vets-website form, save in progress functionality, or prefill, please [reach out to the Platform on slack for](https://depo-platform-documentation.scrollhelp.site/support/getting-help-from-the-platform-in-slack) additional options.

The vets-api Platform is a wrapper around VA data services with utilities and tools that support interaction with those services on behalf of a Veteran. It exposes tools to retrieve information and submit data to VA systems, and does so with a unified sign-in mechanism. When services are down or are experiencing problems, vets-api integrations are designed to gracefully handle failures and provide useful notifications to consumers. vets-api is built on top of Ruby on Rails, providing a unified JSON-based REST interface and additional resilience for VA data services that may not be designed to operate directly with users 24x7.

## Platform features

* Authentication and authorization
* PDF generation
* Monitoring
* Exception tracking
* [Downtime Notifications](https://depo-platform-documentation.scrollhelp.site/developer-docs/downtime-notifications)/Maintenance Windows

## Development

See the vets-api Development documentation to get started with a local instance of vets-api and for guidance on how to submit changes and new features.

## Integration overview

A vets-api integration must handle user requests, validate inputs, make one or multiple requests to another (external) service, and then render a response based on the results of those external service responses. To expose a service integration, a developer must:

1. Provide routing for a new endpoint on [api.va.gov](http://api.va.gov)
2. Authorize requests to this endpoint appropriately through a policy
3. Validate user input or form submissions
4. Instantiate an External Service client connection and interact with an External Service
5. Serialize and render response data

vets-api provides utilities and patterns for appropriate instrumentation, error handling, and documentation for defining this integration consistently and resiliently. Refer to the guides in the sidebar for more information on how to utilize each of these features and develop an integration.

### QA Best Practices

### 1. Test locally (and in review instances) as you build forms (and other functionality).

* Write Unit Tests to test form (or other) functionality.
* Write End-to-End Tests to test how a form (or other) functionality interacts with other services, e.g., a data source.

### 2. Test your code after it has been merged to master and is on staging

When your complete and final build has been code reviewed and merged:

* Conduct Manual Functional Testing
* Conduct Cross-browser Manual Testing.
* Conduct Manual Accessibility/508 Compliance Testing.
* Conduct User Acceptance Testing

### Best practices for QA testing

This document describes the Platform’s recommended process for QA testing.

Recommended QA testing process flow

## Determine what type of testing your product needs

The type of testing your product needs depends on the what type of changes you’re making. Use the criteria listed below to help determine what type of testing is required.

* Front-end unit test - always write unit tests, and aim for 80% coverage!
* Back-end unit test - always write unit tests!
* End-to-end test - always create at least one spec that verifies the happy path of your product then create additional tests for other high impact user journeys
* Manual functional test - if you are creating new functionality in your product then it is prudent to execute targeted manual functional testing for each new function
* Exploratory test - if time permits, set aside 30 minutes to conduct testing in a `preview environment` or `staging` at the end of the sprint where you integrate new functionality, and before the change is released to `production`
* 508/Accessibility test - always conduct accessibility testing and use automated and manual test
* User acceptance test - if the stories your team is integrating into the product were derived from stakeholders with continued involvement in the product, then facilitate user acceptance test sessions with those stakeholders in order to validate the acceptance criteria have been completed

## Create a test plan

A test plan is a collection of test runs that make it easier to create multiple runs at once. Use the **Description** field for your test plan to describe the changes and reference the relevant product outline and user stories.

Please note that you will likely need access to [TestRail](https://dsvavsp.testrail.io/) in order to access many of these artifacts. See “**TestRail access**” under [Request access to tools: additional access for developers](https://depo-platform-documentation.scrollhelp.site/getting-started/request-access-to-tools#Requestaccesstotools-Additionalaccessfordevelopers) for information on getting access.

[Example TestRail Test Plan](https://dsvavsp.testrail.io/index.php?/auth/login/L3BsYW5zL3ZpZXcvMzAtN2MyNWNiMWU1YjhlYTYxNTkyZDBhZDAyNzI2MmRkZDcwZGM1ZGMwMzQzY2I4ZGMyOWQ2YjI1NzVkYmU3MzhjMA::) for reference

## Create test cases

Use TestRail to [create test cases](https://depo-platform-documentation.scrollhelp.site/developer-docs/Creating-a-test-case-in-TestRail.1736441938.html) as you build. Be sure to link to the relevant user story in the **Reference** field of the test case.

[Sample Test Case Collection](https://dsvavsp.testrail.io/index.php?/auth/login/L3N1aXRlcy92aWV3LzImZ3JvdXBfYnk9Y2FzZXM6c2VjdGlvbl9pZCZncm91cF9vcmRlcj1hc2MtZjc1YzJmMDgzZmViOGZhMmIzMWU2MWFkYzY4OWNmZmNjNjBmZDU3NzVmODdhMjkzOWQ0NjRjYmY0MTU2ODM4Mw::) for reference

## User stories

A single user story may require several test cases to provide full coverage. See example scenarios below.

| **User Story**: As a VA.gov user, I need to be able to check for existing appointments at a VA facility. | | |
| --- | --- | --- |
| Scenario 1 | Auth on Appointment Page with appointment | 1. VA landing page 2. Navigate to the appointment page 3. Login as user with existing appointment 4. Verify existing appointment |
| Scenario 2 | Auth on Landing Page with appointment | 1. VA landing page 2. Login as user with existing appointment 3. Navigate to the appointment page 4. Verify existing appointment |
| Scenario 3 | Auth on Landing Page without appointment | 1. VA landing page 2. Login as user with no appointments 3. Navigate to appointment page 4. Verify no existing appointments 5. Create new appointment |

## Execute tests

Once you’ve created your test cases and a test run, you’ll want to [execute the test](https://depo-platform-documentation.scrollhelp.site/developer-docs/Executing-tests-in-TestRail.1738768387.html) through the TestRail interface.

## Log results

As you execute your tests, you can use TestRail to mark each step as pass or fail. In addition, when you encounter a failing step you should log the failure as a defect in the form of VA.gov-team GitHub issue and link the defect to the step and test case that failed. If you log your results as you execute your test plan you can achieve strong traceability between the execution of tests and the defects discovered during execution.

## Report results

After you’ve created a test plan, linked references, executed the test plan, and linked defects where appropriate; it’s time to report the results of your QA testing efforts to stakeholders. TestRail includes several built-in templates that can be used for reporting.

We require specific QA reports at certain points in the development process as part of the [collaboration cycle](https://depo-platform-documentation.scrollhelp.site/collaboration-cycle/). For a detailed description of the Platform’s QA requirements, see [Platform QA Standards](https://depo-platform-documentation.scrollhelp.site/developer-docs/quality-assurance-standards).

### Coding best practices for PII

Last Updated: February 14, 2025

This document covers coding best practices related to [Personal Identifiable Information (PII)](https://vfs.atlassian.net/wiki/x/DAB8q) that are intended to protect the privacy and security of VA.gov users and comply with federal privacy regulations.

Detailed information on PII, including examples, can be found at [Personally Identifiable Information (PII) and Protected Heath Information (PHI)](https://vfs.atlassian.net/wiki/x/DAB8q) and PII guidelines.

## Don’t put PII into URLs or query strings

Putting PII (such as user-provided addresses or postal codes) in a URL or query string is problematic because it's logged as query strings into Splunk and other platforms, including Google Analytics and other platforms. Because of how the logging works, it’s possible to link log entries back to individual users.

A user-friendly and secure approach is to use POST, rather than GET, and put a "Share" button on the page, which will copy the URL with the encrypted address/token onto the clipboard for the user to share. Using this approach, the PII won’t show up in the URL or query string, and therefore doesn't get logged to Splunk, etc.

More information on URLs can be found on [VA.gov Design System URL standards](https://design.va.gov/content-style-guide/url-standards).

## PII’s Impact on the Design System

The following Design System content and components are at a higher risk of containing PII. Take special care when working with these items.

### Components:

* [URLs](https://design.va.gov/components/url-standards/)
* [Breadcrumbs](https://design.va.gov/components/breadcrumbs)
* [Links](https://design.va.gov/components/link/)
* [Buttons](https://design.va.gov/components/button/)
* Selection form fields

  + [Checkboxes](https://design.va.gov/components/form/checkbox)
  + [Radio buttons](https://design.va.gov/components/form/radio-button)
  + [Select component](https://design.va.gov/components/form/select)
* Open text fields

  + [Text input](https://design.va.gov/components/form/text-input)
  + [Textarea](https://design.va.gov/components/form/textarea)
* [Search input](https://design.va.gov/components/search-input)

### Content style guide items:

* [Title tags](https://design.va.gov/content-style-guide/title-tags)
* [Alternative text for images](https://design.va.gov/content-style-guide/alternative-text-for-images)
* [Error messages](https://design.va.gov/content-style-guide/error-messages/)

### Platform Best Practices - Unit and e2e Tests

Last Updated: May 26, 2025

The Platform’s test suites form the backbone of our continuous integration (CI) pipeline. By following the guidance in this page, VFS teams can ensure that the tests for their applications/forms are running both efficiently and effectively.

Consideration for these practices should include recognition of the Platform’s transition from React to web components, as lead by the Design System Team. Unit tests for application functionality layered atop web components may be warranted, but web components themselves are already comprehensively tested by Design System Team engineers.

What problem did web components solve that React components could not?

A large portion of the <http://VA.gov> site is built through the content-build application, which uses Liquid templates. The teams building the Liquid templates had created their own implementations of the React components. This meant that

* these implementations did not get any upgrades or fixes that were applied to the React components
* implementations of these components were uneven across the static pages
* teams were responsible for fixing a variety of issues on their own, including accessibility issues, which were also unevenly applied

By moving to web components, we

* reduced the amount of work required to maintain component implementations
* improved consistency across component implementations, including consistency between static pages and React applications

The Design System Team has done our best to make adoption as easy as possible.

* We’ve added React bindings so that React teams are able to use the components without too much extra work.
* We’ve added migration scripts that automate the migration from the React component to the web component.
* As we release new web components, we’ve been reaching out to teams who use the older React version and encouraging them to migrate. In some cases we have assisted with that process as well.

As teams have adjusted to the use of the web components, we’ve seen the adoption rate increase as well. For example, the `va-loading-indicator` component has been adopted pretty quickly and most of the migrations were done by the frontend teams.

## Unit Testing

* Unit tests should validate **logic within individual components or functions**, not UI behavior or rendering.

  + Unit tests are designed to validate internal logic, not external dependencies like API calls. Introducing API calls can lead to brittle tests that fail due to network issues or external system changes.

    - Mock APIs and external dependencies to ensure unit tests remain focused and isolated.
    - Reset mocks and stubs between tests to avoid state leakage.

      * This can be accomplished with the use of `node-fetch` and `sinon`.

        import chai,  from 'chai';
        import sinon from 'sinon';
        import fetch from 'node-fetch';
        import  from '../src/api.js';
        describe('fetchUser', () => {
        let stub;
        beforeEach(() => {
        stub = sinon.stub(global, 'fetch');
        });
        afterEach(() => stub.restore());
        it('resolves JSON when ok', async () => {
        stub.resolves() });
        const user = await fetchUser(1);
        });
        it('rejects on non-ok', () => {
        stub.resolves();
        return expect(fetchUser(2)).to.be.rejectedWith('Network error: 404');
        });
        });
        const callback = sinon.spy();
        myAsyncFunction(arg, callback);
        // later on in the test…
        sinon.assert.calledOnce(callback);
        sinon.assert.calledWith(callback, expectedValue);

* Testing dates and times

  + Dates and times can be mocked for better reliability that isn’t vulnerable to leap days, daylight savings, AWS region migrations, or other unexpected circumstances.
  + Utilize date utility libraries to manage time-sensitive logic effectively.

    - `mockdate` is one such tool already used in `vets-website`.

      * <https://www.npmjs.com/package/mockdate>
* Use callbacks to signal test step completion or to handle events. Like Mocha’s `done()`:

  it('reads a file via callback', done => {
  fs.readFile('foo.txt', 'utf8', (err, data) => {
  expect(err).to.be.null;
  expect(data).to.equal('hello');
  done();
  });
  });

* Enzyme has been deprecated, as it is incompatible with React 19+. Platform now supports the use of the React Testing Library (RTL).

  + Legacy tests using Enzyme may eventually require phased updates to keep up with Platform standards.
* The upcoming Node 22 upgrade may present issues for tests that manipulate `window` properties. Specific mocks may be required to handle such test cases.

## Cypress e2e Testing

* Teams should use **E2E tests** for complex interactions or full application flows.

  + This is where you want to perform shadow DOM testing. Cypress support for the testing of shadow DOM elements is far more robust than Mocha. Some teams may encounter situations where some unit tests would be best converted into e2e tests to ensure effective test coverage.
* Real API calls *can* be used in e2e tests, but this choice introduces a risk of test failures resulting from network issues or external system changes.

  + The `cy.intercept()` Cypress command can be used to stub out your app’s network requests during testing. By returning predefined responses instantly, it both avoids flaky real‑server calls and speeds up your test suite.

    - This command can be used anywhere before a request would be fired:

      * Inside an `it()` block:

        it('shows error after failed login', () => {
        cy.intercept('POST', '/api/login', ).as('loginFail');
        cy.get('button[type=submit]').click();
        cy.wait('@loginFail');
        });
      * Inside a `describe()` block as part of a `before()` or `beforeEach()` hook, where it can be used multiple times:

        describe('My flow', () => {
        before(() => {
        cy.intercept('GET', '/api/profile', ).as('getProfile');
        });
        it('does something that triggers that request', () => {
        cy.visit('/');
        cy.wait('@getProfile');
        // …
        });
        });
* Larger response objects to be mocked can be kept in a separate file and imported as necessary.
* There are several helper files already in use throughout `vets-website`, with `src/platform/testing/e2e/mock-helpers.js` being one such example.
* `vets-api` endpoints use `rspec` for test automation. While Cypress should not be used to establish adequate endpoint test coverage, there may be cases where teams find value in using real API calls in their e2e tests.

### Potential pain points

* If `cy.visit()` is the last command used in a test block, Cypress may hang if a redirect occurs, like in this example:

  Cypress hangs because it is not expecting the /education/submit-school-feedback/configuration page.

  + An assertion can be added after such a command to ensure that the redirect is occurring as expected.
* Overly large `it()` blocks

  + Extensive testing performed in a single block may be convenient for certain reasons, but it can result in a flaky test spec.

    - Stack traces used during debugging may not provide useful direction beyond identifying the block containing problematic code.

      * If evaluating a flow that logs in, reaches user profile data, checks messages, then searches for a completed form, what was the failure point? Login? Session timeout? An unexpected redirect?
* Using test users to perform real logins within test specs

  + This is another opportunity to use mocks. Test user data can be manipulated by anyone with access to the TUD, so specs relying on static test user credentials and user state will be vulnerable to unintentional interference.
* Using `async/await` with `waitFor` may result in the conditionals of `waitFor` to not be properly processed before test scripts proceed.

### Visually hidden link and button text best practices

Last Updated: July 7, 2025

When the visual name of a link or button isn’t descriptive enough for screen readers, we typically use `aria-label` or `aria-labelledby` to create a more specific accessible name.

This can be an issue for users of speech recognition applications, who may struggle to select interactive elements when the visual name doesn't match the accessible name.

This page details best practices for creating accessible names that work for all users.

true

When the visual name of a link or button isn’t descriptive enough for screen readers, we typically use `aria-label` or `aria-labelledby` to create a more specific accessible name. This can be an issue for users of speech recognition applications, who may struggle to select interactive elements when the visual name doesn't match the accessible name. This page details best practices for creating accessible names that work for all users.

## Glossary

|  |  |
| --- | --- |
| **Speech recognition applications** | Built-in or third-party apps that allow users to control their devices by using their voice. This includes navigating websites and filling out online forms. Also known as “voice command applications.”  Apps include Dragon (Windows, third-party), Voice Control (Mac and iOS, built-in), and Speech Recognition (Windows 10, built-in).  Example: to activate a link with the visible name “My Profile” on a web page, a user of a voice command app can say “Click ‘My Profile.’” to activate the link.  For more about how speech recognition applications work, read Speech recognition instructions and troubleshooting during research. |
| **Accessible name (accName)** | From [W3.org](https://www.w3.org/TR/accname-1.2/):  The name of a user interface element. The value of the accessible name may be derived from a visible (e.g., the visible text on a button) or invisible (e.g., the text alternative that describes an icon) property of the user interface element. |
| **aria-label, aria-labelledby** | ARIA methods for defining an element’s accessible name, used when the design doesn’t allow for unique visible text strings |

## Why non-visible accessible names can be an issue

VA.gov often uses non-visible accessible names to enhance the accessibility a web page.

A common example are VA’s [form review pages](https://design.va.gov/templates/forms/review).

* These pages allow users to edit their form entries before submission.
* Each form section has an edit button. The visible name of each button is “Edit.”
* Since duplicate “Edit” buttons have no context (*what* is being edited?), we use an `aria-label` to create an accessible name for each button. The "Edit" button under "Personal information" has an `aria-label` of "Edit personal information." This allows screen reader users to determine the intent of each button.

But this can be an issue for voice command users who try to select a link or button.

* Some applications only allow users to use a non-visible accessible name (if present) to select elements on the page.
* Some only use the visual name. For those apps, if a user tries the accessible name, it won’t work.
* Some allow for a mix of both, drawing from the visible and accessible name to make a selection.

This results in an inconsistent experience for these users.

## How to use non-visible accessible names

First, **review your design**. If possible, use distinct visual names for each link / button on a screen. This avoids the issue of needing `aria-label` or `aria-labelledby` entirely.

If your design doesn’t allow for this and you must use a non-visible accessible name, follow these guidelines:

1. **Create the accessible name.** If there’s a visible name, the accessible name must start with that name.

   1. **Correct:** A button with the visible name “Edit” is given the accessible name “Edit personal information”
   2. **Incorrect:** A button with the visible name “Submit” is given the accessible name “Please submit the form”
2. **Add the accessible name using the correct method.**

   1. **VADS components:** Use the component’s built-in prop.

      1. Check the prop list for the component in Storybook. For example, the [Button component](https://design.va.gov/storybook/?path=/docs/uswds-va-button--docs) has a `label` prop, which is defined as “The aria-label of the component.”
      2. If the component doesn’t have an `aria-label` equivalent, you can’t create a non-visible accessible name for that component.
      3. **Don’t use “aria-label”** - the component will only recognize built-in props.
   2. **Custom code:** Use one of these three options, in this order:

      1. `aria-labelledby` with visible text

         1. Accessible names created with `aria-labelledby` are machine translatable. Since they “live” in the actual text of the page, if you need to edit that text, the accessible name will be edited too!
         2. In this example, the button’s accessible name is “Edit Personal information”

            <h2 id="theHeading">Personal information</h2>
            <button id="theButton" aria-labelledby="theButton theHeading">Edit</button>
      2. `aria-labelledby` and the `.vads-u-visibility--screen-reader` class

         1. If you don’t have visible text to work with, you can create some visually hidden text using the VADS `.vads-u-visibility--screen-reader` utility class. Put it in a container, give it an ID, and reference it.
         2. In this example, the link’s accessible name is “Hello Friend”

            <div id="someText" class="vads-u-visibility--screen-reader"> Friend</div>
            <a href="#" id="moreText" aria-labelledby="someText moreText">Hello</a>
      3. `aria-label` - only use if necessary

         1. Like `alt`, `aria-label` is generally not translated by machine translation because the label is in an HTML attribute.
         2. If you use `aria-label`, remember to edit it if necessary. Since `aria-label` isn’t visible and is “trapped” as an attribute, it’s often forgotten about after initial development.

## Resources

* TPGi: [What is an accessible name?](https://www.tpgi.com/what-is-an-accessible-name/)
* VA GitHub: [Voice Command and Interactive Elements Testing](https://github.com/department-of-veterans-affairs/va.gov-team/issues/92432)

**Full Platform Documentation**: https://vfs.atlassian.net/wiki/spaces/pilot

---
