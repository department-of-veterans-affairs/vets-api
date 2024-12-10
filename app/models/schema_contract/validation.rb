# frozen_string_literal: true

module SchemaContract
  class Validation < ApplicationRecord
    self.table_name = 'schema_contract_validations'

    attribute :contract_name, :string
    attribute :user_uuid, :string
    attribute :response, :jsonb
    attribute :error_details, :string

    validates :contract_name, presence: true
    validates :user_uuid, presence: true
    validates :response, presence: true
    validates :status, presence: true

    enum :status, %i[initialized success schema_errors_found schema_not_found error], default: :initialized
  end
end
