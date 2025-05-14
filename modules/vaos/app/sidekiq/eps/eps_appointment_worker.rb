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
    # @param user [User] the user associated with the appointment
    # @param retry_count [Integer] the current retry count (default: 0)
    def perform(appointment_id, user, retry_count = 0)
      service = Eps::AppointmentService.new(user)
      begin
        response = service.get_appointment(appointment_id:)
        if appointment_finished?(response)
          # Appointment finished successfully, do nothing
        elsif retry_count < MAX_RETRIES
          self.class.perform_in(1.minute, appointment_id, user, retry_count + 1)
        else
          Eps::VaNotifyAppointmentWorker.perform_async(user, 'Could not complete booking')
        end
      rescue Common::Exceptions::BackendServiceException
        Eps::VaNotifyAppointmentWorker.perform_async(user, 'Service error, please contact support')
      rescue => e
        Eps::VaNotifyAppointmentWorker.perform_async(user, e.message)
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
  end
end
