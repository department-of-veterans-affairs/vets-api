# 3. Stub Classes and Proxy Calls

Date: 2024-07-10

## Status

Accepted

## Context

These models are required or used throughout our code and should not be considered as part of the pensions module.

1. modules/pensions/app/models/pensions/form_submission.rb
1. modules/pensions/app/models/pensions/form_submission_attempt.rb
1. modules/pensions/app/models/pensions/in_progress_form.rb
1. modules/pensions/app/models/pensions/persistent_attachment.rb
1. modules/pensions/app/models/pensions/persistent_attachments/pension_burial.rb
1. modules/pensions/app/models/pensions/form_submission.rb
1. modules/pensions/app/models/pensions/form_submission_attempt.rb
1. modules/pensions/lib/pensions/lighthouse/benefits_intake/service.rb
1. modules/pensions/lib/pensions/lighthouse/benefits_intake/metadata.rb

There are quite a few other package references in this job:

1. CentralMail
1. Datadog
1. Sidekiq
1. Common
1. Vets::SharedLogging (formerly SentryLogging)
2. Statsd

## Decision

We will remove these proxy/stub models when possible and reference the root project as its own dependency.

## Consequences

Remove the proxy classes and document the dependencies instead. Document the files we are using in the calls.
