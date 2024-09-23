# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Debt < Common::Resource
      attribute :id, Types::String
      attribute :file_number, Types::String.optional.default(nil)
      attribute :payee_number, Types::String.optional.default(nil)
      attribute :deduction_code, Types::String.optional.default(nil)
      attribute :benefit_type, Types::String.optional.default(nil)
      attribute :diary_code, Types::String.optional.default(nil)
      attribute :diary_code_description, Types::String.optional.default(nil)
      attribute :amount_overpaid, Types::Float.optional.default(nil)
      attribute :amount_withheld, Types::Float.optional.default(nil)
      attribute :original_a_r, Types::Float.optional.default(nil)
      attribute :current_a_r, Types::Float.optional.default(nil)
      attribute :debt_history, Types::Array do
        attribute :date, Types::Date
        attribute :letter_code, Types::String
        attribute :description, Types::String
      end
    end
  end
end
