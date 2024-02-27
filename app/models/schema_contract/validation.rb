# frozen_string_literal: true

module SchemaContract
  class Validation < ApplicationRecord
    self.table_name = 'schema_contract_validations'

    attribute :name, :string
    attribute :user_uuid, :string
    attribute :response, :jsonb
    attribute :status, :string
    attribute :error_details, :string
    # enum :status, { initialized: 0, success: 1, schema_errors_found: 2, schema_not_found: 3 }
  end
end
