# frozen_string_literal: true

module CentralMail
  class SubmitForm4142Cleanup
    include Sidekiq::Worker

    FORM_ID = '21-4142'

    def perform(user_uuid)
      user = User.find(user_uuid)

      # Delete SiP form on successful submission
      InProgressForm.form_for_user(FORM_ID, user)&.destroy
    end
  end
end
