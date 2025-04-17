# frozen_string_literal: true

class UserActionEventSerializer
  include JSONAPI::Serializer

  attribute :details, :created_at, :updated_at, :event_type, :identifier
end
