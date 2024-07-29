# frozen_string_literal: true

class PaymentHistorySerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :payment_history

  attribute :payments
  attribute :return_payments
end
