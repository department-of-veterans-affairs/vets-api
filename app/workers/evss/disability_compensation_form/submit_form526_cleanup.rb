# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526Cleanup < Job
      include Sidekiq::Worker

      FORM_ID = '21-526EZ'

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
