# frozen_string_literal: true

class SchedulingPreferencesSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :scheduling_preferences

  attribute :preferences do |object|
    object[:preferences]
  end
end
