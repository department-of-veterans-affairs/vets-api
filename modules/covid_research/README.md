# COVID Research

The COVID Research module currently serves one very small function.  It exists to process Corona Virus Research volunteer submissions.  There is currently **only one** route in this entire module.

## Metrics

There are a few basic metrics around this functionality:

  * submissions received (`api_covid_research_volunteer_create_total`)
  * submissions delivered to `genISIS` (`api_covid_research_volunteer_deliver_form_total`)
  * invalid submissions (`api_covid_research_volunteer_create_fail`)
  * `genISIS` delivery failures (`api_covid_research_volunteer_deliver_form_fail`)

## Architecture

There are four main pieces that are used in support of this feature/behavior:

  * Vets Website
  * Vets API
  * Sidekiq
  * `genISIS`

This module sits between `va.gov` and `genISIS`.  Its purpose is to receive submissions from `vets-website`, validate them and then deliver the data to `genISIS`.

## Data Flow

The data flow for this module is pretty simple.  There is currently a single form that is handled here.  The module validates the submission, delivers a confirmation email and submits it to `genISIS` for long term storage.

  1. Form received from va.gov ([#create](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/app/controllers/covid_research/volunteer/submissions_controller.rb))
  2. Form validated against the JSON Schema ([#valid?](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/app/services/covid_research/volunteer/form_service.rb))
     1. Form encrypted and enqueued in Sidekiq ([#queue_delivery](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/app/services/covid_research/volunteer/form_service.rb))
     2. Confirmation email delivery enqueued in Sidekiq ([#create](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/app/controllers/covid_research/volunteer/submissions_controller.rb))
  3. Form data delivered to `genISIS` (via Sidekiq) ([#deliver_form](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/app/services/covid_research/volunteer/genisis_service.rb))
  4. Confirmation email delivered (via Sidekiq) ([#perform](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/app/workers/covid_research/volunteer/confirmation_mailer_job.rb))

## Schema Changes

This module currently has a few specs that are dependent on the data format.  That data format is defined outside of this module (in `vets_json_schema`) and therefore there is some coordination required if that data format changes.

If the [schema](https://github.com/department-of-veterans-affairs/vets-json-schema/blob/master/dist/COVID-VACCINE-TRIAL-schema.json) changes then matching changes need to be made to the following fixtures:

  * [valid-submission.json](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/spec/fixtures/files/valid-submission.json)
  * [encrypted-form.json](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/spec/fixtures/files/encrypted-form.json)
  * [genisis-mapping.json](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/spec/fixtures/files/genisis-mapping.json)

Updating `valid-submission.json` and `genisis-mapping.json` should be fairly straight forward the `encrypted-form.json` fixture is a different story.  The best way to update that file is to use the rails console and encrypt the **updated** `valid-submission.json` fixture.

There is a [Rake task](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/covid_research/lib/tasks/covid_research_tasks.rake) that does not currently run but does document what needs to be done in the console to generate a new version of `encrypted-form.json`.
