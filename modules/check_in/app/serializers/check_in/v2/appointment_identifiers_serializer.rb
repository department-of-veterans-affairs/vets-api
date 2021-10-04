# frozen_string_literal: true

module CheckIn
  module V2
    class AppointmentIdentifiersSerializer
      include FastJsonapi::ObjectSerializer

      set_id(&:uuid)
      set_type :appointment_identifier

      attribute :patientDFN do |object|
        object.payload.dig(:'read.full', :appointments).first[:patientDFN]
      end

      attribute :stationNo do |object|
        object.payload.dig(:'read.full', :appointments).first[:stationNo]
      end
    end
  end
end
