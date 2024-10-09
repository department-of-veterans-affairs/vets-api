# frozen_string_literal: true

class ServiceHistorySerializer
  include JSONAPI::Serializer

  set_id { '' }

  attributes :service_history do |object|
    object[:episodes]
  end

  attributes :vet_status_eligibility do |object|
    object[:vet_status_eligibility]
  end
end
