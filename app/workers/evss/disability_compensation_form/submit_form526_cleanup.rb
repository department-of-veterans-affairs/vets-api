# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526Cleanup
      include Sidekiq::Worker

      FORM_ID = '21-526EZ'

      def perform(user_uuid)
        user = User.find(user_uuid)

        # Delete SiP form on successfull submission
        InProgressForm.form_for_user(FORM_ID, user)&.destroy
        EVSS::IntentToFile::ResponseStrategy.delete("#{user.uuid}:compensation")
      end
    end
  end
end
