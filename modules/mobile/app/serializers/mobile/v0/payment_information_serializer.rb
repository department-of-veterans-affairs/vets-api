# frozen_string_literal: true

module Mobile
  module V0
    class PaymentInformationSerializer
      include FastJsonapi::ObjectSerializer

      set_type :paymentInformation
      attributes :account_control, :payment_account

      def initialize(id, payment_account, account_control, options = {})
        payment_account&.account_number = StringHelpers.mask_sensitive(payment_account&.account_number)
        payment_account&.account_type += ' account'
        resource = PaymentInformationStruct.new(id, payment_account, account_control)
        super(resource, options)
      end
    end

    PaymentInformationStruct = Struct.new(:id, :payment_account, :account_control)
  end
end
