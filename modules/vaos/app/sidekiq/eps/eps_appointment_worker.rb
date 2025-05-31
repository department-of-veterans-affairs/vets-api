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
  # a pending state. If the maximum retries are reached, it sends a failure message
  # via VaNotify to the user's email address.
  class EpsAppointmentWorker
    include Sidekiq::Worker

    MAX_RETRIES = 3

    ##
    # Performs the job to process the appointment.
    #
    # @param appointment_id [String] the ID of the appointment to process
    # @param user_uuid [String] the UUID of the user
    # @param retry_count [Integer] the current retry count (default: 0)
    # @return [Boolean] true if successful, false otherwise
    # @raise [ArgumentError] if user is not found or has no email
    # @raise [Common::Exceptions::BackendServiceException] if the appointment service call fails
    # @note Errors are caught, logged, and a notification is sent to the user when possible.
    #       For ArgumentError, only logs the error.
    #       For BackendServiceException, sends a generic service error message.
    #       For other StandardError, sends the actual error message.
    def perform(appointment_id, user_uuid, retry_count = 0)
      user = find_user(user_uuid)
      user_email = get_user_email(user)

      appt_response = fetch_appointment(appointment_id, user)
      handle_appointment_status(appt_response, appointment_id, user_uuid, user_email, retry_count)
    rescue ArgumentError => e
      log_worker_error(e, user_uuid, include_error_message: true)
      false
    rescue Common::Exceptions::BackendServiceException => e
      log_worker_error(e, user_uuid)
      if defined?(user_email) && user_email.present?
        send_vanotify_message(email: user_email, error: 'Service error, please contact support')
      end
      false
    rescue => e
      log_worker_error(e, user_uuid)
      if defined?(user_email) && user_email.present?
        send_vanotify_message(email: user_email, error: e.message)
      end
      false
    end

    private

    ##
    # Find a user by UUID and validate it exists
    #
    # @param user_uuid [String] the UUID of the user
    # @return [User] the User object
    # @raise [ArgumentError] if the user is not found
    def find_user(user_uuid)
      user = User.find(user_uuid)
      raise ArgumentError, 'User not found' unless user

      user
    end

    ##
    # Get a user's email and validate it exists
    #
    # @param user [User] the User object
    # @return [String] the user's email
    # @raise [ArgumentError] if the email is not found
    def get_user_email(user)
      user_email = user.va_profile_email
      raise ArgumentError, 'Email not found for user' if user_email.blank?

      user_email
    end

    ##
    # Check the status of an appointment
    #
    # @param appointment_id [String] the ID of the appointment to check
    # @param user [User] the User object
    # @return [Object] the response from the appointment service
    # @raise [Common::Exceptions::BackendServiceException] if the service call fails
    def fetch_appointment(appointment_id, user)
      service = Eps::AppointmentService.new(user)
      service.get_appointment(appointment_id:)
    end

    ##
    # Handle the appointment status based on the service response
    #
    # @param response [Object] the response from the appointment service
    # @param appointment_id [String] the ID of the appointment
    # @param user_uuid [String] the UUID of the user
    # @param user_email [String] the user's email
    # @param retry_count [Integer] the current retry count
    # @return [Boolean] true if appointment is finished, false otherwise
    def handle_appointment_status(appt_response, appointment_id, user_uuid, user_email, retry_count)
      unless appt_response.try(:state) == 'submitted'
        if retry_count < MAX_RETRIES
          self.class.perform_in(1.minute, appointment_id, user_uuid, retry_count + 1)
        else
          send_vanotify_message(email: user_email, error: 'Could not complete booking')
        end
      end

      true
    end

    ##
    # Log an error with worker failure information and user UUID if available
    #
    # @param error [StandardError] the error to log
    # @param user_uuid [String, nil] the UUID of the user, if available
    # @param include_error_message [Boolean] whether to include the error message in the log (default: false)
    # @return [void]
    def log_worker_error(error, user_uuid = nil, include_error_message: false)
      uuid_info = user_uuid.present? ? "for user UUID: #{user_uuid}" : 'missing user UUID'

      error_message = if include_error_message
                        "EpsAppointmentWorker FAILED #{uuid_info}: #{error.message}"
                      else
                        "EpsAppointmentWorker FAILED #{uuid_info}: #{error.class}"
                      end

      Rails.logger.error(error_message)
    end

    ##
    # Sends a failure message via VaNotify with error details.
    #
    # @param email [String] the email address to send the message to
    # @param error [String, nil] the error message to include in the notification (default: nil)
    # @return [void]
    # @note The error message is passed to the VaNotify template as a parameter
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
