# frozen_string_literal: true

class PaymentHistorySerializer < ActiveModel::Serializer
  type :payment_history

  attribute :payments
  attribute :return_payments

  def id
    nil
  end
end
