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

      attribute :appointmentIEN do |object|
        object.payload[:appointments].first[:appointmentIEN]
      end

      attribute :icn do |object|
        object.payload.dig(:demographics, :icn) || object.payload[:appointments].first[:icn]
      end

      attribute :mobilePhone do |object|
        object.payload.dig(:demographics, :mobilePhone)
      end

      attribute :patientCellPhone do |object|
        object.payload[:patientCellPhone]
      end

      attribute :facilityType do |object|
        object.payload[:facilityType]
      end

      attribute :edipi do |object|
        object.payload[:appointments].first[:edipi]
      end
    end
  end
end
