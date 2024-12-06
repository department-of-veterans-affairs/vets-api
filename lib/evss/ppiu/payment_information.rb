# frozen_string_literal: true

require 'vets/model'
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
      include Vets::Model

      attribute :control_information, EVSS::PPIU::ControlInformation
      attribute :payment_account, EVSS::PPIU::PaymentAccount
      attribute :payment_address, EVSS::PPIU::PaymentAddress
      attribute :payment_type, String

      delegate :authorized?, to: :control_information

      def payment_account
        authorized? ? @payment_account : EVSS::PPIU::PaymentAccount.new
      end

      def payment_address
        authorized? ? @payment_address : EVSS::PPIU::PaymentAddress.new
      end
    end
  end
end
