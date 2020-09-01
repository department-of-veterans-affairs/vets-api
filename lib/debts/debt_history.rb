# frozen_string_literal: true

module Debts
  class DebtHistory
    include Virtus.model

    attribute :date, String
    attribute :letter_code, String
    attribute :description, String
  end
end
