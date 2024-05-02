# frozen_string_literal: true

module CheckIn
  module VAOS
    class AppointmentSerializer
      include JSONAPI::Serializer

      set_id(&:id)
      set_type :appointments

      attributes :kind, :status, :serviceType, :locationId, :clinic, :start, :end, :minutesDuration
    end
  end
end
