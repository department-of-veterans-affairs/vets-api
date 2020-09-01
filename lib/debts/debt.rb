# frozen_string_literal: true

module Debts
  class Debt
    include Virtus.model

    attribute :file_number, Integer
    attribute :payee_number, String
    attribute :person_entitled, String
    attribute :deduction_code, String
    attribute :benefit_type, String
    attribute :amount_overpaid, Integer
    attribute :amount_withheld, Integer
    attribute :original_ar, Integer
    attribute :current_ar, Integer
    attribute :debt_history, [Debts::DebtHistory]
  end
end
