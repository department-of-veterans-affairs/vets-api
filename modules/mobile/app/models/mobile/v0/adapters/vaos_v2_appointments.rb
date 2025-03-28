# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      # Due to backwards compatibility requirements, this adapter takes in VAOS V2
      # schema and outputs Mobile V0 appointments. Eventually this will be rolled
      # off in favor of Mobile Appointment V2 model.
      #
      # @example create a new instance and parse incoming data
      #   Mobile::V0::Adapters::VAOSV2Appointments.new.parse(appointments)
      #
      class VAOSV2Appointments
        # Takes a result set of VAOS v2 appointments from the appointments web service
        # and returns the set adapted to a common schema.
        #
        # @appointments Hash a list of variousappointment types
        #
        # @return Hash the adapted list
        #
        def parse(appointments)
          return [] if appointments.nil?

          appointments.map do |appointment_hash|
            appointment_adapter = VAOSV2Appointment.new(appointment_hash)
            appointment_adapter.build_appointment_model
          end.compact
        end
      end
    end
  end
end
