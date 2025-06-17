# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526Cleanup < Job
      include Sidekiq::Job
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_cleanup'

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']
        timestamp = Time.now.utc
        form526_submission_id = msg['args'].first

        form_job_status = Form526JobStatus.find_by(job_id:)
        bgjob_errors = form_job_status.bgjob_errors || {}
        new_error = {
          "#{timestamp.to_i}": {
            caller_method: __method__.to_s,
            error_class:,
            error_message:,
            timestamp:,
            form526_submission_id:
          }
        }
        form_job_status.update(
          status: Form526JobStatus::STATUS[:exhausted],
          bgjob_errors: bgjob_errors.merge(new_error)
        )

        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

        ::Rails.logger.warn(
          'Submit Form 526 Cleanup Retries exhausted',
          { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }
        )
      rescue => e
        ::Rails.logger.error(
          'Failure in SubmitForm526Cleanup#sidekiq_retries_exhausted',
          {
            messaged_content: e.message,
            job_id:,
            submission_id: form526_submission_id,
            pre_exhaustion_failure: {
              error_class:,
              error_message:
            }
          }
        )
        raise e
      end

      # Cleans up a 526 submission by removing its {InProgressForm}
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        Sentry.set_tags(source: '526EZ-all-claims')
        super(submission_id)
        with_tracking('Form526 Cleanup', submission.saved_claim_id, submission.id) do
          InProgressForm.find_by(form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: submission.user_uuid)&.destroy
        end
      end
    end
  end
end
