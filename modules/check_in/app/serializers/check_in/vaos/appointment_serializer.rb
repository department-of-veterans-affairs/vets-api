# frozen_string_literal: true

module CheckIn
  module VAOS
    class AppointmentSerializer
      include JSONAPI::Serializer

      set_id(&:id)
      set_type :appointments

      attributes :kind, :status, :serviceType, :locationId, :clinic, :start, :end, :minutesDuration

      attribute :telehealth do |object|
        {
          vvsKind: object.dig('telehealth', 'vvsKind'),
          atlas: object.dig('telehealth', 'atlas')
        }
      end

      attribute :extension do |object|
        {
          preCheckinAllowed: object.dig('extension', 'preCheckinAllowed'),
          eCheckinAllowed: object.dig('extension', 'eCheckinAllowed'),
          patientHasMobileGfe: object.dig('extension', 'patientHasMobileGfe')
        }
      end

      attribute :serviceCategory do |object|
        object.serviceCategory&.map { |category| { text: category['text'] } }
      end

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

      attribute :clinicServiceName do |object|
        object.dig(:clinicInfo, :data, :serviceName)
      end

      attribute :clinicPhysicalLocation do |object|
        object.dig(:clinicInfo, :data, :physicalLocation)
      end

      attribute :clinicFriendlyName do |object|
        object.dig(:clinicInfo, :data, :friendlyName)
      end
    end
  end
end
