# frozen_string_literal: true

require 'evss/intent_to_file/response_strategy'

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526Cleanup < Job
      include Sidekiq::Worker
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_cleanup'

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      # :nocov:
      sidekiq_retries_exhausted do |msg, _ex|
        job_exhausted(msg, STATSD_KEY_PREFIX)
      end
      # :nocov:

      # Cleans up a 526 submission by removing its {InProgressForm} and deleting the
      # active Intent to File record (via EVSS)
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        Raven.tags_context(source: '526EZ-all-claims')
        super(submission_id)
        with_tracking('Form526 Cleanup', submission.saved_claim_id, submission.id) do
          InProgressForm.find_by(form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: submission.user_uuid)&.destroy
          EVSS::IntentToFile::ResponseStrategy.delete("#{submission.user_uuid}:compensation")
        end
      end
    end
  end
end
