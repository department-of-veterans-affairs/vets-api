# frozen_string_literal: true

module DebtManagementCenter
  class Payment
    include Virtus.model
    attribute :education_amount, String
    attribute :compensation_amount, String
    attribute :veteran_or_spouse, String
  end
end
