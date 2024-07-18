# frozen_string_literal: true

# NOTE: I don't think is being used anywhere
class DependentsApplicationSerializer
  include JSONAPI::Serializer

  attribute :guid
  attribute :state
  attribute :parsed_response
end
