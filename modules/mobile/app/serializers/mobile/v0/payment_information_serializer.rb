# frozen_string_literal: true

module Mobile
  module V0
    class PaymentInformationSerializer
      include JSONAPI::Serializer

      set_type :paymentInformation
      attributes :account_control, :payment_account
    end
  end
end
