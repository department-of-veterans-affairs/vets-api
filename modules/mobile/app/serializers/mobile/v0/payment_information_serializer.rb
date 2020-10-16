# frozen_string_literal: true

module Mobile
  module V0
    class PaymentInformationSerializer
      include FastJsonapi::ObjectSerializer

      set_type :PaymentInformation
      attributes :paymentInformation

      def initialize(id, paymentInformation, options = {})
        resource = PaymentInformationStruct.new(id, paymentInformation)
        super(resource, options)
      end
    end

    PaymentInformationStruct = Struct.new(:id, :paymentInformation)
  end
end