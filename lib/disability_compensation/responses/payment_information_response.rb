# frozen_string_literal: true

module DisabilityCompensation
  module ApiProvider
    # Used in conjunction with the PPIU/Direct Deposit Provider
    class PaymentInformation
      include ActiveModel::Serialization
      include Virtus.model

      # TODO: Implement in #59698
      # TODO: When Lighthouse implementation is in progress, convert these to generic objects
      # attribute :control_information, EVSS::PPIU::ControlInformation
      # attribute :payment_account, EVSS::PPIU::PaymentAccount
      # attribute :payment_address, EVSS::PPIU::PaymentAddress
      # attribute :payment_type, String
    end

    class PaymentInformationResponse
      include ActiveModel::Serialization
      include Virtus.model

      attribute :responses, Array[DisabilityCompensation::ApiProvider::PaymentInformation]
    end
  end
end
