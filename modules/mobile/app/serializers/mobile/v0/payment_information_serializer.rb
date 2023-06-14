# frozen_string_literal: true

module Mobile
  module V0
    class PaymentInformationSerializer
      include JSONAPI::Serializer

      set_type :paymentInformation
      attributes :account_control, :payment_account

      def initialize(id, payment_account, account_control, options = {})
        account_control = if Flipper.enabled?(:mobile_lighthouse_direct_deposit)
                            account_control.to_h
                          else
                            account_control.to_h.merge(can_update_payment: account_control.authorized?)
                          end
        payment_account&.account_number = StringHelpers.mask_sensitive(payment_account&.account_number)
        resource = PaymentInformationStruct.new(id, payment_account.to_h, account_control)
        super(resource, options)
      end
    end

    PaymentInformationStruct = Struct.new(:id, :payment_account, :account_control)
  end
end
