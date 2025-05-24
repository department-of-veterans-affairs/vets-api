# frozen_string_literal: true

module Eps
  ##
  # VaNotifyAppointmentWorker is responsible for handling the VA Notify messaging
  # for appointment notifications.
  #
  # This worker is isolated from the main appointment processing to allow for
  # separate retry configuration specific to notification delivery.
  class VaNotifyAppointmentWorker
    include Sidekiq::Worker

    sidekiq_options retry: 12

    ##
    # Performs the job to send a notification via VA Notify.
    #
    # @param user [User] the user to send the notification to
    # @param error [String] the error message to include in the notification
    def perform(user, error)
      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)

      notify_client.send_email(
        email_address: user.va_profile_email,
        template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
        parameters: { 'error' => error }
      )
    rescue => e
      Rails.logger.error("VA Notify appointment notification failed: #{e.message}")
      raise
    end
  end
end