# frozen_string_literal: true

require 'vets/model'

module DebtManagementCenter
  class Payment
    include Vets::Model

    attribute :education_amount, String
    attribute :compensation_amount, String
    attribute :veteran_or_spouse, String
  end
end
