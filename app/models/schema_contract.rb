# frozen_string_literal: true

class SchemaContract < ApplicationRecord
  attribute :name, :string
  attribute :user_uuid #string?
  attribute :response, :jsonb

  attribute :status
  enum status: [:initiated, :success, :schema_errors_found, :invalid_response, :validation_file_not_found, :invalid_schema_file]
end