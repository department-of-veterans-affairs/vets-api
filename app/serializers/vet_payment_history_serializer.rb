# frozen_string_literal: true

class VetPaymentHistorySerializer < ActiveModel::Serializer
  type :payment_history

  attribute :payments
  attribute :return_payments

  def id
    nil
  end

  def payments
    object[:payments]
  end

  def return_payments
    object[:return_payments]
  end
end
