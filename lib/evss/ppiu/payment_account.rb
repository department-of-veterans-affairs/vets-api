# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module PPIU
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

      validates :account_type, presence: true
      validates :financial_institution_name, presence: true
      validates :account_number, presence: true
      validates :financial_institution_routing_number, presence: true

      validates_format_of :account_number, with: ACCOUNT_NUM_REGEX
      validates_format_of :financial_institution_routing_number, with: ROUTING_NUM_REGEX
    end
  end
end
