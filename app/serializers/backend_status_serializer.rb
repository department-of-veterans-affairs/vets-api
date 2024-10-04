# frozen_string_literal: true

# TO-DO: After transition of Post-911 GI Bill to 24/7 availability, confirm
# serializer and related logic can be completely removed
class BackendStatusSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :name
  attribute :service_id
  attribute :is_available, &:available?
  attribute :uptime_remaining
end
