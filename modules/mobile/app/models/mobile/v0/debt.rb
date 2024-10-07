# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Debt < Common::Resource
      attribute :id, Types::String
      attribute :file_number, Types::String
      attribute :payee_number, Types::String
      attribute :person_entitled, Types::String
      attribute :deduction_code, Types::String
      attribute :benefit_type, Types::String
      attribute :diary_code, Types::String
      attribute :diary_code_description, Types::String
      attribute :amount_overpaid, Types::Float
      attribute :amount_withheld, Types::Float
      attribute :original_ar, Types::Float
      attribute :current_ar, Types::Float
      attribute :debt_history, Types::Array do
        attribute :date, Types::Date
        attribute :letter_code, Types::String
        attribute :description, Types::String
      end
    end
  end
end
