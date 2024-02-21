# frozen_string_literal: true
module SchemaContract
  class SchemaContractTest < ApplicationRecord
    attribute :name, :string
    attribute :user_uuid, :string
    attribute :response, :jsonb
    attribute :status, :string
    attribute :error_details, :string
    # enum status: { initiated: 0, success: 1, schema_errors_found: 2, invalid_response: 3,
                  #  validation_file_not_found: 4, invalid_schema_file: 5 }
  end
end
