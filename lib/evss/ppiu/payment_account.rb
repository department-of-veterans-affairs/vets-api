# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module PPIU
    ##
    # Model for a user's payment account
    #
    # @!attribute account_type
    #   @return [String] The type of account, i.e. "Checking" or "Savings"
    # @!attribute financial_institution_name
    #   @return [String] The name of the financial institution
    # @!attribute account_number
    #   @return [String] The account number; digits only
    # @!attribute financial_institution_routing_number
    #   @return [String] The routing number of the financial institution; exactly 9 digits
    #
    class PaymentAccount
      include Virtus.model
      include ActiveModel::Validations
      include ActiveModel::Serialization

      ACCOUNT_NUM_REGEX = /\A\d*\z/
      ROUTING_NUM_REGEX = /\A\d{9}\z/

      attribute :account_type, String
      attribute :financial_institution_name, String
      attribute :account_number, String
      attribute :financial_institution_routing_number, String

      validates :account_type, inclusion: { in: %w[Checking Savings] }, presence: true
      validates :account_number, presence: true
      validates :financial_institution_routing_number, presence: true

      validates_format_of :account_number, with: ACCOUNT_NUM_REGEX
      validates_format_of :financial_institution_routing_number, with: ROUTING_NUM_REGEX
    end
  end
end
