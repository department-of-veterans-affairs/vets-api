# frozen_string_literal: true

class ServiceHistorySerializer
  include JSONAPI::Serializer

  set_id { '' }

  attributes :service_history do |object|
    object
  end
end
