# frozen_string_literal: true

class SchemaContract < ApplicationRecord

  attribute :name, :string
  attribute :last_user_uuid #string?
  attribute :last_response, :jsonb
  attribute :schema, :string
  attribute :status
end