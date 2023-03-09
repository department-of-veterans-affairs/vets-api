# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class PaymentHistorySerializer
      include JSONAPI::Serializer
      set_type :payment_history

      attributes :account,
                 :amount,
                 :bank,
                 :date,
                 :payment_method,
                 :payment_type
    end
  end
end
