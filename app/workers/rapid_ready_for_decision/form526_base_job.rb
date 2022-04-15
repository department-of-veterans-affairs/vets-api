# frozen_string_literal: true

require 'lighthouse/veterans_health/client'
require 'sidekiq/form526_job_status_tracker/job_tracker'
require 'sidekiq/form526_job_status_tracker/metrics'

module RapidReadyForDecision
  class Form526BaseJob
    STATSD_KEY_PREFIX = 'worker.fast_track.form526_base_job'

    include Sidekiq::Worker
    include Sidekiq::Form526JobStatusTracker::JobTracker

    extend SentryLogging
    # NOTE: This is apparently at most about 4.5 hours.
    # https://github.com/mperham/sidekiq/issues/2168#issuecomment-72079636
    sidekiq_options retry: 8

    class NoRrdProcessorForClaim < StandardError; end

    def perform(form526_submission_id)
      form526_submission = Form526Submission.find(form526_submission_id)

      begin
        processor_class = RapidReadyForDecision::Constants.processor_class(form526_submission)
        raise NoRrdProcessorForClaim unless processor_class

        with_tracking(self.class.name, form526_submission.saved_claim_id, form526_submission_id) do
          return if form526_submission.pending_eps?

          processor = processor_class.new(form526_submission)
          processor.run
        end
      rescue => e
        # only retry if the error was raised within the "with_tracking" block
        retryable_error_handler(e) if @status_job_title
        message = "Sidekiq job id: #{jid}. The error was: #{e.message}.<br/>" \
                  "The backtrace was:\n #{e.backtrace.join(",<br/>\n ")}"
        form526_submission.send_rrd_alert_email('Rapid Ready for Decision (RRD) Job Errored', message)
        raise
      end
    end
  end
end
