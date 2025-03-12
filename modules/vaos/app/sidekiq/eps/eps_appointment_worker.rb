# frozen_string_literal: true

module Eps
  ##
  # EpsAppointmentWorker is a Sidekiq worker that polls the EPS service to check the status of an appointment.
  # It retries up to a maximum number of times before sending a failure message if the appointment is not completed.
  #
  class EpsAppointmentWorker
    include Sidekiq::Worker

    MAX_RETRIES = 3

    @retry_count = 0

    ##
    # Performs the Sidekiq job to check the status of an appointment.
    #
    # @param appointment_id [String] The ID of the appointment to check.
    # @param retry_count [Integer] The current retry count (default is 0).
    #
    def perform(appointment_id, user)
      service = Eps::AppointmentService.new(user)
      begin
        # Poll get_appointments with the appointment_id to check if the appointment has finished submitting
        response = service.get_appointment(appointment_id:)
        if appointment_finished?(response)
          # Appointment finished successfully, do nothing
        elsif retry_count < MAX_RETRIES
          # Re-enqueue the worker to poll again after a delay
          self.class.perform_in(1.minute, appointment_id, retry_count + 1)
        else
          # Max retries reached, send failure message
          send_vanotify_message(success: false, error: 'Could not complete booking')
        end
      rescue => e
        send_vanotify_message(success: false, error: e.message)
      end
    end

    private

    ##
    # Checks if the appointment has finished successfully.
    #
    # @param response [OpenStruct] The response from the EPS service.
    # @return [Boolean] True if the appointment is completed or booked, false otherwise.
    #
    def appointment_finished?(response)
      response.state == 'completed' || response.appointmentDetails&.status == 'booked'
    end

    ##
    # Checks if the appointment has failed.
    #
    # @param response [OpenStruct] The response from the EPS service.
    # @return [Boolean] True for status 'booking-failed', 'cancel-failed' or if there is an error. Default false
    #
    def appointment_failed?(response)
      appointment_status = response.appointmentDetails&.status
      appointment_status == 'booking-failed' || appointment_status == 'cancel-failed' || response.error.present?
    end

    ##
    # Sends a failure message via VANotify.
    #
    # @param success [Boolean] Indicates if the operation was successful.
    # @param error [String, nil] The error message, if any.
    #
    def send_vanotify_message(success:, error: nil)
      unless success
        # Code to send failure message via VANotify with error details
      end
    end
  end
end
