# frozen_string_literal: true

module VAOS
  module V2
    class AppointmentsCheckInSerializer
      include JSONAPI::Serializer

      set_type :appointments

      attributes :id,
                 :kind,
                 :status,
                 :service_type,
                 :location_id,
                 :clinic,
                 :telehealth,
                 :reason,
                 :start,
                 :end,
                 :minutes_duration,
                 :slot,
                 :requested_periods,
                 :contact,
                 :preferred_times_for_phone_call,
                 :priority,
                 :cancellation_reason,
                 :description,
                 :comment,
                 :preferred_language,
                 :practitioner_ids

      attribute :identifier do |object|
        object['identifier'].pluck('value')
      end

      attribute :serviceTypes do |object|
        object['serviceTypes'].pluck('text')
      end

      attribute :serviceCategory do |object|
        object['serviceCategory'].pluck('text')
      end

      attribute :reasonCode do |object|
        object['reasonCode']['text']
      end

      attribute :patientIcn do |object|
        object['patientIcn']
      end

      attribute :practitioners do |object|
        object['practitioners'].map do |practitioner|
          {
            identifier: practitioner['identifier'].pluck('value'),
            name: practitioner['name'],
            address: practitioner['address']
          }
        end
      end

      attribute :preferredLocation do |object|
        {
          city: object['preferredLocation']['city'],
          state: object['preferredLocation']['state']
        }
      end

      attribute :cancelationReason do |object|
        object['cancelationReason']['text']
      end

      attribute :preferredTimesForPhoneCall do |object|
        object['preferredTimesForPhoneCall']
      end
    end
  end
end
