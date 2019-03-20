# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526Cleanup < Job
      include Sidekiq::Worker

      FORM_ID = '21-526EZ'
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_cleanup'

      # Cleans up a 526 submission by removing its {InProgressForm} and deleting the
      # active Intent to File record (via EVSS)
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        super(submission_id)
        with_tracking('Form526 Cleanup', submission.saved_claim_id, submission.id) do
          InProgressForm.find_by(form_id: FORM_ID, user_uuid: submission.user_uuid)&.destroy
          EVSS::IntentToFile::ResponseStrategy.delete("#{submission.user_uuid}:compensation")
        end
      end
    end
  end
end
