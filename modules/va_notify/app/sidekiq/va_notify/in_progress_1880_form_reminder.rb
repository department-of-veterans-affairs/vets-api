# frozen_string_literal: true

require 'va_notify/in_progress_form_helper'

module VANotify
  class InProgress1880FormReminder
    include Sidekiq::Job
    include Vets::SharedLogging
    sidekiq_options retry: 14

    FORM_NAME = '26-1880'
    API_KEY_PATH = 'Settings.vanotify.services.va_gov.api_key'

    def perform(form_id)
      return unless Flipper.enabled?(:in_progress_1880_form_reminder)

      in_progress_form = InProgressForm.find(form_id)

      veteran = VANotify::Veteran.new(in_progress_form)

      return if veteran.first_name.blank?
      return if veteran.icn.blank?

      template_id = Settings.vanotify.services.va_gov.template_id.form1880_reminder_email
      personalisation_details = {
        'first_name' => veteran.first_name.upcase,
        'date' => in_progress_form.expires_at.strftime('%B %d, %Y')
      }

      if Flipper.enabled?(:va_notify_v2_in_progress_form_reminder)
        send_v2_reminder(in_progress_form.user_account_id, template_id, personalisation_details)
      else
        OneTimeInProgressReminder.perform_async(in_progress_form.user_account_id, FORM_NAME, template_id,
                                                personalisation_details)
      end
    rescue VANotify::Veteran::MPINameError, VANotify::Veteran::MPIError
      nil
    end

    private

    def send_v2_reminder(user_account_id, template_id, personalisation_details)
      return if InProgressRemindersSent.find_by(user_account_id:, form_id: FORM_NAME)

      InProgressRemindersSent.create!(user_account_id:, form_id: FORM_NAME)
      V2::QueueUserAccountJob.enqueue(user_account_id, template_id, personalisation_details, API_KEY_PATH)
    end
  end
end
