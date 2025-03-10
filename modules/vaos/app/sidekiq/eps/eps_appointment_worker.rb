# frozen_string_literal: true

class EpsAppointmentWorker
  include Sidekiq::Worker

  def perform(appointment_id)
    service = Eps::AppointmentService.new
    begin
      # Poll get_appointments with the appointment_id to check if the appointment has finished submitting
      # (Add logic here to determine if the appointment has finished submitting based on the response)
      response = service.get_appointment(appointment_id:)
      if appointment_finished?(response)
        # Appointment finished successfully
        send_vanotify_message(success: true)
      else
        # Re-enqueue the worker to poll again after a delay
        self.class.perform_in(1.minutes, appointment_id)
      end
    rescue StandardError => e
      send_vanotify_message(success: false, error: e.message)
    end
  end

  private

  def appointment_finished?(response)
    # Check if the appointment state is 'completed' or the status is 'booked'
    response.state == 'completed' || response.appointmentDetails&.status == 'booked'
  end

  def send_vanotify_message(success:, error: nil)
    if success
      # Code to send success message via VANotify
    else
      # Code to send failure message via VANotify with error details
    end
  end
end