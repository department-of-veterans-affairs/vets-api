# frozen_string_literal: true

module CheckIn
  module V2
    class AppointmentIdentifiersSerializer
      include JSONAPI::Serializer

      set_id(&:id)
      set_type :appointment_identifier

      attribute :patientDFN do |object|
        object.payload[:appointments].first[:patientDFN]
      end

      attribute :stationNo do |object|
        object.payload[:appointments].first[:stationNo]
      end

      attribute :icn do |object|
        object.payload.dig(:demographics, :icn)
      end

      attribute :mobilePhone do |object|
        object.payload.dig(:demographics, :mobilePhone)
      end

      attribute :patientCellPhone do |object|
        object.payload[:patientCellPhone]
      end
    end
  end
end
