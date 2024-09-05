# frozen_string_literal: true

class CommunicationGroupsSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :hashes

  attribute :communication_groups do |object|
    object[:communication_groups]
  end
end
