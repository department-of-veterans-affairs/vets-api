# frozen_string_literal: true

require 'sidekiq'

module VANotify
  class OneTimeInProgressReminder
    include Sidekiq::Worker

    attr_reader :user_account_id, :form_name

    def perform(user_account_id, form_name, template_id, personalisation)
      @user_account_id = user_account_id
      @form_name = form_name

      return if user_already_notified?

      user_account = UserAccount.find(user_account_id)

      InProgressRemindersSent.create!(user_account_id:, form_id: form_name)
      VANotify::IcnJob.perform_async(user_account.icn, template_id, personalisation)
    end

    private

    def user_already_notified?
      InProgressRemindersSent.find_by(user_account_id:, form_id: form_name)
    end
  end
end
