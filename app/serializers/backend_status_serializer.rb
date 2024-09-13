# frozen_string_literal: true

class BackendStatusSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :name
  attribute :service_id
  attribute :is_available do |object|
    object.available?
  end
  attribute :uptime_remaining
end
