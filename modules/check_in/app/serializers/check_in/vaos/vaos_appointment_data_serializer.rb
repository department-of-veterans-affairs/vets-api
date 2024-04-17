# frozen_string_literal: true

module CheckIn
  module VAOS
    class VAOSAppointmentDataSerializer
      include JSONAPI::Serializer

      keys_to_serialize = %i[id identifier kind status serviceType locationId clinic start end extension]

      set_id(&:id)

      attribute :appointments do |object|
        object.data.map do |data|
          data.select { |key| keys_to_serialize.include?(key) }
        end
      end
    end
  end
end
