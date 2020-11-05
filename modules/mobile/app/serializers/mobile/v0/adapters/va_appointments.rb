# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class VAAppointments
        def parse(appointments)
          appointments.dig('data', 'appointmentList')
        end
      end
    end
  end
end
