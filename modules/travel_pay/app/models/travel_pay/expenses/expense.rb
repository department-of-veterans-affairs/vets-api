# frozen_string_literal: true

require 'active_model'

module TravelPay
  class Expense
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :claim_id, :receipt, :purchase_date, :description, :cost_requested

    validates :claim_id, :purchase_date, :description, :cost_requested, presence: true

    def initialize(claim_id:, purchase_date:, description:, cost_requested:, receipt: nil)
      @claim_id = claim_id
      @purchase_date = purchase_date
      @description = description
      @cost_requested = cost_requested
      @receipt = receipt # Receipt instance or nil
    end
  end
end
