## Sidekiq Job Development

### Objective
Write a Sidekiq job, test it locally, and run it via Rails console (local or staging/prod).

### Sidekiq admin UIs
| http://localhost:3000/sidekiq | https://staging-api.va.gov/sidekiq | https://api.va.gov/sidekiq |
| --- | --- | --- |

### What is a Sidekiq job?
A Sidekiq job is a queued unit of work. In vets-api, the standard queues are `low`, `default`, and `high`. If you do not specify a queue, the job uses `default` (most vets-api jobs do).

### When to use Sidekiq jobs
Use Sidekiq for work that must be queued, retried, or scheduled. Examples in vets-api:

- Some form submissions
- Evidence submissions
- Scheduled reports (ex: weekly)
- Admin-only tasks run on demand via Rails console

Sidekiq jobs can:
- Be scheduled
- Take arguments
- Retry a set number of times
- Batch or chain work
- Enforce throttling / rate limiting

Sidekiq jobs need to:
- Use JSON-serializable arguments
- Avoid keyword args (Sidekiq does not support them). Use an options hash.
  - OK: `def perform(options = {})` and `perform(one: 1, two: 2)`
  - Avoid: `def perform(one:, two:)`
- Be idempotent (safe to re-run). We do not always follow this yet.
- Avoid PII or sensitive data in arguments

### Examples in vets-api
Most Sidekiq jobs live in [app/workers](https://github.com/department-of-veterans-affairs/vets-api/tree/master/app/workers). Shared utilities and admin jobs may live in [lib/sidekiq](https://github.com/department-of-veterans-affairs/vets-api/tree/master/lib/sidekiq).

- EVSS 526 jobs: [app/workers/evss](https://github.com/department-of-veterans-affairs/vets-api/tree/master/app/workers/evss)
- Appeals evidence upload job: [app/workers/decision_review/submit_upload.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/workers/decision_review/submit_upload.rb)
- Form 4142 submission job: [app/workers/decision_review/form4142_submit.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/workers/decision_review/form4142_submit.rb)

```ruby
# frozen_string_literal: true

require 'decision_review_v1/utilities/constants'
require 'decision_review_v1/service'

module DecisionReview
  class Form4142Submit
    include Sidekiq::Worker

    STATSD_KEY_PREFIX = 'worker.decision_review.form4142_submit'

    sidekiq_options retry: 3

    def decrypt_form(encrypted_payload)
      JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_payload))
    end

    def perform(appeal_submission_id, encrypted_payload, submitted_appeal_uuid)
      decision_review_service.process_form4142_submission(
        appeal_submission_id:,
        rejiggered_payload: decrypt_form(encrypted_payload)
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      ::Rails.logger.error({
                             error_message: e.message,
                             form_id: DecisionReviewV1::FORM4142_ID,
                             parent_form_id: DecisionReviewV1::SUPP_CLAIM_FORM_ID,
                             message: 'Supplemental Claim Form4142 Queued Job Errored',
                             appeal_submission_id:,
                             lighthouse_submission: {
                               id: submitted_appeal_uuid
                             }
                           })
      raise e
    end

    private

    def decision_review_service
      DecisionReviewV1::Service.new
    end
  end
end
```

`include Sidekiq::Worker` marks a class as a job. `perform` is the required entry point for the work. This example passes an encrypted payload because the data is not in the database and cannot contain PII in plain-text args.

### Admin-style job example
[NonBreakeredForm526BackgroundLoader](https://github.com/department-of-veterans-affairs/vets-api/blob/84bd1d89b98194fb261908e2134c7f1fa099813e/lib/sidekiq/form526_backup_submission_process/processor.rb#L416) uploads a zipped PDF representation of a 526 submission to S3.

```ruby
class NonBreakeredForm526BackgroundLoader
  extend ActiveSupport::Concern
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(id)
    NonBreakeredProcessor.new(
      id,
      get_upload_location_on_instantiation: false,
      ignore_expiration: true
    ).upload_pdf_submission_to_s3
  end
end
```

Run it from Rails console:
```ruby
Sidekiq::Form526BackupSubmissionProcess::NonBreakeredForm526BackgroundLoader.perform(1234)
```
This queues the job for submission ID `1234`.

## Walkthrough: build a real job
This is an actual VBA request: weekly stats on 526 claims. The focus is on Sidekiq-ifying the task.

Start with the query:
```ruby
sdate = 7.days.ago.beginning_of_week.beginning_of_day
edate = Date.today.beginning_of_week.beginning_of_day
total = Form526Submission.where('created_at BETWEEN ? AND ?', sdate, edate)
total_count = total.count
exhausted = total.where(submitted_claim_id: nil).size
no_ids = total.where(submitted_claim_id: nil).where(backup_submitted_claim_id: nil)
totally_failed_ids = no_ids.map(&:form526_job_statuses).select do |jss|
  jss.any? { |js| js.job_class == 'BackupSubmission' && js.status == 'exhausted' }
end.map { |e| e.first.form526_submission_id }
still_pending = no_ids.pluck(:id) - totally_failed_ids
```

Create a job next to [app/workers/evss/failed_claims_report.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/workers/evss/failed_claims_report.rb), for example `app/workers/evss/weekly_backup_submission_report.rb`:

```ruby
# frozen_string_literal: true

module EVSS
  class WeeklyErrorReportMailer < ApplicationMailer
    def build(recipients:, body:)
      mail(
        to: recipients,
        subject: 'Weekly 526 Error Report',
        content_type: 'text/html',
        body:
      )
    end
  end

  class WeeklyBackupSubmissionReport
    include Sidekiq::Worker

    def perform(recipients, start_date = 7.days.ago.beginning_of_week.beginning_of_day,
                end_date = Time.zone.today.beginning_of_week.beginning_of_day)
      Rails.logger.info(
        "Sending Weekly Backup Submission Report for #{start_date} - #{end_date}, to #{recipients}"
      )
      total = Form526Submission.where('created_at BETWEEN ? AND ?', start_date, end_date)
      total_count = total.count
      exhausted = total.where(submitted_claim_id: nil).size
      no_ids = total.where(submitted_claim_id: nil).where(backup_submitted_claim_id: nil)
      totally_failed_ids = no_ids.map(&:form526_job_statuses).select do |jss|
                             jss.any? do |js|
                               js.job_class == 'BackupSubmission' && js.status == 'exhausted'
                             end
                           end.map { |e| e.first.form526_submission_id }
      still_pending = no_ids.pluck(:id) - totally_failed_ids
      body = ["#{start_date} - #{end_date}"]
      body << %(Total Submissions: #{total_count})
      body << %(Total Number of auto-establish Failures: #{exhausted})
      body << %(Successful Backup Submissions: #{exhausted - no_ids.count})
      body << %(Failed Backup Attempts: #{totally_failed_ids.count})
      body << %(Still Pending/Attempting Submission: #{still_pending.size})
      body << %(Submission IDs Pending: #{still_pending})
      WeeklyErrorReportMailer.build(recipients:, body: body.join('<br>')).deliver_now
    end
  end
end
```

Test it locally:
```ruby
EVSS::WeeklyBackupSubmissionReport.perform_async('kyle.soskin@adhocteam.us')
```

To run synchronously in console:
```ruby
require 'sidekiq/testing'
EVSS::WeeklyBackupSubmissionReport.drain
```

Next step is to add test cases and open a PR (example: [#13412](https://github.com/department-of-veterans-affairs/vets-api/pull/13412)).

### Batching
Batching groups related jobs and lets you enforce order. Example from [app/models/form526_submission.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/3678ce92445d97b73dae8af9efe14650ec6e3aff/app/models/form526_submission.rb#L87) for the 526 submission workflow:

```ruby
def start_evss_submission_job
  workflow_batch = Sidekiq::Batch.new
  workflow_batch.on(
    :success,
    'Form526Submission#perform_ancillary_jobs_handler',
    'submission_id' => id,
    # Call get_first_name while the temporary User record still exists
    'first_name' => get_first_name
  )
  job_ids = workflow_batch.jobs do
    EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.perform_async(id)
  end

  job_ids.first
end
```
It uses a callback: "on success of all jobs in the batch, run the ancillary jobs." Then it loads the single submission job into the batch.

### Rate limiting
Most useful docs: [Sidekiq Enterprise rate limiting](https://github.com/sidekiq/sidekiq/wiki/Ent-Rate-Limiting).

Example used in staging (safe to copy/paste there to experiment):

```ruby
ids = Form526Submission.last(1000).pluck(:id)
batch = Sidekiq::Batch.new
limitter = Sidekiq::Limiter.concurrent('Form526BackupSubmission', 32, wait_timeout: 120, lock_timeout: 60)
ids.each do |id|
  batch.jobs do
    limitter.within_limit do
      Sidekiq::Form526BackupSubmissionProcess::NonBreakeredForm526BackgroundLoader.perform_async(id)
    end
  end
end
```

This creates a limiter named `Form526BackupSubmission`. Within this limiter, at most 32 jobs run concurrently.

Queued vs running matters: `wait_timeout` is how long a queued job waits before erroring; `lock_timeout` is the max time a single job can hold the lock. If a job hangs, the lock is released after `lock_timeout` so another job can proceed (the hung job may keep running).

