# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class AppointmentRequests
        # accepts an array of appointment requests
        # returns a list of appointments (as open structs), filtering out any that are not SUBMITTED or CANCELLED
        def parse(requests)
          va_appointments = []
          cc_appointments = []

          requests.each do |request|
            status = Templates::BaseAppointment.status(request)
            next unless status.in?(%w[CANCELLED SUBMITTED])

            if request.cc_appointment_request
              cc_appointments << Templates::CommunityCareAppointment.new(request).appointment
            else
              va_appointments << Templates::VAAppointment.new(request).appointment
            end
          end

          [va_appointments, cc_appointments]
        end
      end
    end
  end
end
