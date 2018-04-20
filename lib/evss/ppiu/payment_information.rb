# frozen_string_literal: true

require 'common/models/base'
require 'evss/ppiu/control_information'
require 'evss/ppiu/payment_account'
require 'evss/ppiu/payment_address'

module EVSS
  module PPIU
    class PaymentInformation
      include Virtus.model

      attribute :control_information, EVSS::PPIU::ControlInformation
      attribute :payment_account, EVSS::PPIU::PaymentAccount
      attribute :payment_address, EVSS::PPIU::PaymentAddress
      attribute :payment_type, String
    end
  end
end
