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

    STATSD_PREFIX = 'api.vaos.appointment_status_check'
    MAX_RETRIES = 3

    ##
    # Performs the job to process the appointment.
    #
    # @param appointment_id [String] the ID of the appointment to process
    # @param user [User] the user associated with the appointment
    # @param retry_count [Integer] the current retry count (default: 0)
    def perform(user_uuid, appointment_id_last4, retry_count = 0)
      @user_uuid = user_uuid
      @appointment_id_last4 = appointment_id_last4

      appointment_data = fetch_and_validate_appointment_data
      return unless appointment_data

      appointment_id = appointment_data[:appointment_id]
      email = appointment_data[:email]
      user = User.find(user_uuid)

      process_appointment_status(user, appointment_id, email, retry_count)
    end

    private

    def fetch_and_validate_appointment_data
      redis_client = Eps::RedisClient.new
      appointment_data = redis_client.fetch_appointment_data(uuid: @user_uuid, appointment_id: @appointment_id_last4)

      if appointment_data.nil? || appointment_data[:appointment_id].blank? || appointment_data[:email].blank?
        log_missing_redis_data(appointment_data)
        return nil
      end

      appointment_data
    end

    def log_missing_redis_data(appointment_data)
      Rails.logger.error('EpsAppointmentWorker missing or incomplete Redis data',
                         { user_uuid: @user_uuid, appointment_id_last4: @appointment_id_last4,
                           appointment_data: }.to_json)
      StatsD.increment("#{STATSD_PREFIX}.failure", tags: ["user_uuid: #{@user_uuid}"])
    end

    def process_appointment_status(user, appointment_id, email, retry_count)
      service = Eps::AppointmentService.new(user)
      begin
        response = service.get_appointment(appointment_id:)
        handle_appointment_response(response, email, retry_count)
      rescue Common::Exceptions::BackendServiceException
        send_vanotify_message(email:, error: 'Service error, please contact support')
      rescue => e
        send_vanotify_message(email:, error: e.message)
      end
    end

    def handle_appointment_response(response, email, retry_count)
      if appointment_finished?(response)
        # Appointment finished successfully, do nothing
      elsif retry_count < MAX_RETRIES
        self.class.perform_in(1.minute, @user_uuid, @appointment_id_last4, retry_count + 1)
      else
        send_vanotify_message(email:, error: 'Could not complete booking')
      end
    end

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
    # @param user [User] the user to send the message to
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
