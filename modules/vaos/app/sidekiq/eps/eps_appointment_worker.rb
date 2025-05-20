# frozen_string_literal: true

module Eps
  ##
  # EpsAppointmentWorker is responsible for handling the appointment processing
  # and retrying the job if the appointment is not finished.
  #
  # It includes the Sidekiq::Worker module to leverage Sidekiq's background job
  # processing capabilities.
  #
  # The worker retries the job up to MAX_RETRIES times if the appointment is in
  # a pending state. If the maximum retries are reached, it sends a failure message.
  # EpsAppointmentWorker is responsible for handling the appointment processing
  # and retrying the job if the appointment is not finished.
  class EpsAppointmentWorker
    include Sidekiq::Worker

    MAX_RETRIES = 3

    ##
    # Performs the job to process the appointment.
    #
    # @param appointment_id [String] the ID of the appointment to process
    # @param user_uuid [String] the UUID of the user
    # @param retry_count [Integer] the current retry count (default: 0)
    def perform(appointment_id, user_uuid, retry_count = 0)
      user = User.find(user_uuid)
      return unless user

      user_email = user.va_profile_email
      return unless user_email

      service = Eps::AppointmentService.new(user)
      begin
        response = service.get_appointment(appointment_id:)
        if appointment_finished?(response)
          # Appointment finished successfully, do nothing
        elsif retry_count < MAX_RETRIES
          self.class.perform_in(1.minute, appointment_id, user_uuid, retry_count + 1)
        else
          send_vanotify_message(email: user_email, error: 'Could not complete booking')
        end
      rescue Common::Exceptions::BackendServiceException
        send_vanotify_message(email: user_email, error: 'Service error, please contact support')
      rescue => e
        send_vanotify_message(email: user_email, error: e.message)
      end
    end

    private

    ##
    # Checks if the appointment is finished.
    #
    # @param response [Object] the response object from the appointment service
    # @return [Boolean] true if the appointment is finished, false otherwise
    def appointment_finished?(response)
      response.state == 'completed' || response.appointmentDetails&.status == 'booked'
    end

    ##
    # Sends a failure message via VaNotify with error details.
    #
    # @param email [String] the email address to send the message to
    # @param error [String, nil] the error message (default: nil)
    def send_vanotify_message(email:, error: nil)
      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      notify_client.send_email(email_address: email,
                               template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
                               parameters: {
                                 'error' => error
                               })
    end
  end
end
