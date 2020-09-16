# COVID Research

The COVID Research module currently serves one very small function.  It exists to process Corona Virus Research volunteer submissions.  There is currently **only one** route in this entire module.

## Architecture

There are four main pieces that are used in support of this feature/behavior:

  * Vets Website
  * Vets API
  * Sidekiq
  * `genISIS`

This module sits between `va.gov` and `genISIS`.  Its purpose is to receive submissions from `vets-website`, validate them and then deliver the data to `genISIS`.

## Data Flow

The data flow for this module is pretty simple.  There is currently a single form that is handled here.  The module validates the submission, delivers a confirmation email and submits it to `genISIS` for long term storage.

  1. Form received from va.gov ([#create](app/controllers/covid_research/volunteer/submissions_controller.rb))
  2. Form validated against the JSON Schema ([#valid?](app/services/covid_research/volunteer/form_service.rb))
     1. Form encrypted and enqueued in Sidekiq ([#queue_delivery](app/services/covid_research/volunteer/form_service.rb))
     2. Confirmation email delivery enqueued in Sidekiq ([#create](app/controllers/covid_research/volunteer/submissions_controller.rb))
  3. Form data delivered to `genISIS` (via Sidekiq) ([#deliver_form](app/services/covid_research/volunteer/genisis_service.rb))
  4. Confirmation email delivered (via Sidekiq) ([#perform](app/workers/covid_research/volunteer/confirmation_mailer_job.rb))
