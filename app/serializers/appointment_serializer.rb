# frozen_string_literal: true

class AppointmentSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :appointments
end
