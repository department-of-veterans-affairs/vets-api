# frozen_string_literal: true

module CheckIn
  module VAOS
    class AppointmentSerializer
      include JSONAPI::Serializer

      set_id(&:id)
      set_type :appointments

      attributes :kind, :status, :serviceType, :locationId, :clinic, :start, :end, :minutesDuration

      attribute :facilityName do |object|
        object.dig(:facility, :name)
      end

      attribute :facilityVistaSite do |object|
        object.dig(:facility, :vistaSite)
      end

      attribute :facilityTimezone do |object|
        object.dig(:facility, :timezone, :timeZoneId)
      end

      attribute :facilityPhoneMain do |object|
        object.dig(:facility, :phone, :main)
      end

      attribute :serviceName do |object|
        object.dig(:clinic_info, :data, :serviceName)
      end

      attribute :physicalLocation do |object|
        object.dig(:clinic_info, :data, :physicalLocation)
      end

      attribute :friendlyName do |object|
        object.dig(:clinic_info, :data, :friendlyName)
      end
    end
  end
end
