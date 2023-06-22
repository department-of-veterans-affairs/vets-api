# frozen_string_literal: true

module Lighthouse
  module DirectDeposit
    class PaymentAccount
      include ActiveModel::Model

      attr_accessor :name, :account_number, :routing_number
      attr_writer :account_type

      ACCOUNT_NUM_REGEX = /\A\d*\z/
      ROUTING_NUM_REGEX = /\A\d{9}\z/

      validates :account_type, inclusion: { in: %w[Checking Savings] }, presence: true
      validates :account_number, presence: true
      validates :routing_number, presence: true

      validates_format_of :account_number, with: ACCOUNT_NUM_REGEX
      validates_format_of :routing_number, with: ROUTING_NUM_REGEX

      def account_type
        @account_type&.capitalize
      end
    end
  end
end
