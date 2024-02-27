# frozen_string_literal: true

module SchemaContract
  class Validation < ApplicationRecord
    self.table_name = 'schema_contract_validations'

    attribute :contract_name, :string
    attribute :user_uuid, :string
    attribute :response, :jsonb
    attribute :status, :string
    attribute :error_details, :string

    validates :contract_name, presence: true
    validates :user_uuid, presence: true
    validates :response, presence: true
    validates :status, presence: true
  end
end
