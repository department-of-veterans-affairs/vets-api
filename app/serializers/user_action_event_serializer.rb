# frozen_string_literal: true

class UserActionEventSerializer
  include JSONAPI::Serializer

  attribute :details, :created_at, :updated_at

  has_many :user_actions
end
