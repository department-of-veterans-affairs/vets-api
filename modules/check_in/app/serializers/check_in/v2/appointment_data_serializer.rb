# frozen_string_literal: true

module CheckIn
  module V2
    class AppointmentDataSerializer
      include FastJsonapi::ObjectSerializer

      set_id(&:uuid)
      set_type :appointment_data

      attribute :payload do |object|
        approved_values =
          object.payload.dig(:'read.full', :appointments).map do |appt|
            appt.except!(:patientDFN, :stationNo)
          end

        { appointments: approved_values }
      end
    end
  end
end
