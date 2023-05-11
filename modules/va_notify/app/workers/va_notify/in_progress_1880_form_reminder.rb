# frozen_string_literal: true

require 'va_notify/in_progress_form_helper'

module VANotify
  class InProgress1880FormReminder
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: 14

    FORM_NAME = '26-1880'

    class MissingICN < StandardError; end

    def perform(form_id)
      return unless Flipper.enabled?(:in_progress_1880_form_reminder)

      in_progress_form = InProgressForm.find(form_id)
      veteran = VANotify::Veteran.new(in_progress_form)

      return if veteran.first_name.blank?
      raise MissingICN, "ICN not found for InProgressForm: #{in_progress_form.id}" if veteran.icn.blank?

      template_id = Settings.vanotify.services.va_gov.template_id.form1880_reminder_email
      personalisation_details = {
        'first_name' => veteran.first_name.upcase,
        'date' => in_progress_form.expires_at.strftime('%B %d, %Y')
      }
      OneTimeInProgressReminder.perform_async(in_progress_form.user_account_id, FORM_NAME, template_id,
                                              personalisation_details)
    end
  end
end
