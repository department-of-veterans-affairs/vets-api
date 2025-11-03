# Lighthouse Benefits Intake

Allows a programmatic submission of a form via uploaded PDF to the Lighthouse Benefits Intake API.
The Lighthouse API returns a success on receiving a valid upload, but that does not indicate a successful submission to VBMS.
This service also contains a job to perform polling to the API for the status of a submission.
To allow a form/team agnostic approach to this submission and polling a handler is registered
to provide the uuids to query and processing for handling the response

## Table of Contents

- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Testing](#testing)

## Prerequisites

For local development you need to acquire a sandbox/staging API key:
https://developer.va.gov/explore/api/benefits-intake/sandbox-access

| Requirement | Version | Notes |
|-------------|---------|-------|
| Ruby | 3.1+ | Rails application dependency |
| Rails | 7.0+ | Parent application framework |
| PostgreSQL | 12+ | Database with PostGIS |
| Redis | 6+ | Background job processing |

## Configuration

Within `config/settings.yml` there is an entry for `lighthouse.benefits_intake`.
The values are stored in AWS Parameter store, and can be overriden for local development.

```yaml
lighthouse:
  benefits_intake:
    api_key: <%= ENV['lighthouse__benefits_intake__api_key'] %>
    breakers_error_threshold: 80
    host: <%= ENV['lighthouse__benefits_intake__host'] %>
    path: <%= ENV['lighthouse__benefits_intake__path'] %>
    report:
      batch_size: <%= ENV['lighthouse__benefits_intake__report__batch_size'] %>
      stale_sla: <%= ENV['lighthouse__benefits_intake__report__stale_sla'] %>
    use_mocks: <%= ENV['lighthouse__benefits_intake__use_mocks'] %>
    version: <%= ENV['lighthouse__benefits_intake__version'] %>
```

The running of the job is controlled in `lib/periodic_jobs.rb`

A handler can be registered with the status job in different ways:
1. from within `config/initializers/benefits_intake_submission_status_handlers.rb` directly providing the key and class
2. from within a modules engine initialization, eg. `modules/pensions/lib/pensions/engine.rb`

## Usage Examples

To perform an upload of a form and attachments:

```ruby
intake_service = BenefitsIntake::Service.new
metadata = intake_service.valid_metadata?(metadata:)
form_path = intake_service.valid_document?(document:)
intake_service.request_upload
payload = {
  upload_url: intake_service.location,
  document: form_path,          # generated pdf path for the form
  metadata: metadata.to_json,   # metadata is a Hash
  attachments: attachment_paths # generated pdf path for each attachment; each checked with `valid_document?`
}
intake_service.perform_upload(**payload)
```

To register a handler with the submission status job:

```ruby
# Register our Pension Benefits Intake Submission Handler
::BenefitsIntake::SubmissionStatusJob.register_handler(Pensions::FORM_ID, Pensions::BenefitsIntake::SubmissionHandler)
```

- [burials/benefits_intake/submit_claim_job](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/burials/lib/burials/benefits_intake/submit_claim_job.rb)
- [pensions/benefits_intake/submit_claim_job](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/pensions/lib/pensions/benefits_intake/submit_claim_job.rb)

## API Reference

https://developer.va.gov/explore/api/benefits-intake/docs
https://api.va.gov/internal/docs/benefits-intake/v1/openapi.json

## Testing

```bash
# Run module tests
bundle exec rspec spec/lib/lighthouse/benefits_intake
```

Register a handler with the status job, create a claim, submit the claim to Lighthouse using the service, run the status job providing the claim form_id
