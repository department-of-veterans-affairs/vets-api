# frozen_string_literal: true

module SchemaContract
  class Validation < ApplicationRecord
    self.table_name = 'schema_contract_validations'

    attribute :contract_name, :string
    attribute :user_account_id, :string
    attribute :user_uuid, :string
    attribute :response, :jsonb
    attribute :error_details, :string

    validates :contract_name, presence: true
    validates :user_account_id, presence: true
    validates :user_uuid, presence: true
    validates :response, presence: true
    validates :status, presence: true

    enum :status, { initialized: 0, success: 1, schema_errors_found: 2, schema_not_found: 3, error: 4 },
         default: :initialized
  end
end
