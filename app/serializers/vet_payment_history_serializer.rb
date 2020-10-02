# frozen_string_literal: true

class VetPaymentHistorySerializer < ActiveModel::Serializer
  type :payment_history

  attribute :payments
  attribute :return_payments

  def id
    nil
  end

  def initialize(object, options = nil)
    @formatted_payments = []
    @returned_payments = []
    process_payments(object[:payments][:payment])
    super
  end

  def payments
    @formatted_payments
  end

  def return_payments
    @returned_payments
  end

  private

  def process_payments(all_payments)
    all_payments.each do |payment|
      if payment.dig(:return_payment, :check_trace_number).present?
        @returned_payments << {
          'returned_check_amount': payment[:payment_amount],
          'returned_check_type': payment[:payment_type],
          'returned_check_issue_dt': payment[:payment_date],
          'returned_check_cancel_dt': payment[:return_payment][:return_date],
          'returned_check_number': payment[:return_payment][:check_trace_number],
          'return_reason': payment[:return_payment][:return_reason]
        }
      else
        @formatted_payments << {
          pay_check_dt: payment[:payment_date].to_date,
          pay_check_amount: payment[:payment_amount],
          pay_check_type: payment[:payment_type],
          account_number: mask_account_number(payment[:address_eft]),
          check_address: payment[:check_address]
        }
      end
    end
  end

  def mask_account_number(address_eft, all_but = 4, char = '*')
    return if address_eft.blank?

    account_number = address_eft[:account_number]
    return if account_number.blank?

    account_number&.gsub(/.(?=.{#{all_but}})/, char)
  end
end
