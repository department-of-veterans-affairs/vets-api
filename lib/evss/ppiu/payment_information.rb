# frozen_string_literal: true

require 'common/models/base'
require 'evss/ppiu/control_information'
require 'evss/ppiu/payment_account'
require 'evss/ppiu/payment_address'

module EVSS
  module PPIU
    ##
    # Model for payment information
    #
    # @!attribute control_information
    #   @return [EVSS::PPIU::ControlInformation] Data object to determine if the user can update their address
    # @!attribute payment_account
    #   @return [EVSS::PPIU::PaymentAccount] The user's payment account
    # @!attribute payment_address
    #   @return [EVSS::PPIU::PaymentAddress] The user's payment address
    # @!attribute payment_type
    #   @return [String] The payment type
    #
    class PaymentInformation
      include Virtus.model

      attribute :control_information, EVSS::PPIU::ControlInformation
      attribute :payment_account, EVSS::PPIU::PaymentAccount
      attribute :payment_address, EVSS::PPIU::PaymentAddress
      attribute :payment_type, String
    end
  end
end
