# frozen_string_literal: true

module DebtManagementCenter
  class VaAwardsComposite
    include Virtus.model
    attribute :name, String
    attribute :amount, String
    attribute :veteran_or_spouse, String
  end
end
