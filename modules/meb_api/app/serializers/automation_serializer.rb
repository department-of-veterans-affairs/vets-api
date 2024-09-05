# frozen_string_literal: true

class AutomationSerializer
  include JSONAPI::Serializer

  set_id { '' }
  attributes :claimant, :service_data
end
