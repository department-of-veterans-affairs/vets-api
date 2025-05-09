# frozen_string_literal: true

module Adapters
  class PaymentHistoryAdapter
    attr_accessor :payments, :return_payments

    def initialize(input)
      @input_payment = input&.dig(:payments, :payment)

      if @input_payment.nil? || !Flipper.enabled?(:payment_history)
        @payments = []
        @return_payments = []
      else
        @input_payments = [@input_payment].flatten
        payments, return_payments = @input_payments.partition do |payment|
          payment.dig(:return_payment, :check_trace_number).blank?
        end

        @payments = process_payments(payments)
        @return_payments = process_return_payments(return_payments)
      end
    end

    private

    def process_payments(payments)
      payments.map do |payment|
        {
          pay_check_dt: payment[:payment_date],
          pay_check_amount: ActiveSupport::NumberHelper.number_to_currency(payment[:payment_amount]),
          pay_check_type: payment[:payment_type],
          payment_method: get_payment_method(payment),
          bank_name: payment.dig(:address_eft, :bank_name),
          account_number: mask_account_number(payment[:address_eft])
        }
      end
    end

    def process_return_payments(returned_payments)
      returned_payments.map do |payment|
        {
          returned_check_issue_dt: payment[:payment_date],
          returned_check_cancel_dt: payment[:return_payment][:return_date],
          returned_check_amount: ActiveSupport::NumberHelper.number_to_currency(payment[:payment_amount]),
          returned_check_number: payment[:return_payment][:check_trace_number],
          returned_check_type: payment[:payment_type],
          return_reason: payment[:return_payment][:return_reason]
        }
      end
    end

    def get_payment_method(payment)
      return 'Direct Deposit' if payment.dig(:address_eft, :account_number).present?

      return 'Paper Check' if payment.dig(:check_address, :address_line1).present?

      nil
    end

    def mask_account_number(address_eft, all_but = 4, char = '*')
      return if address_eft.blank?

      account_number = address_eft[:account_number]
      return if account_number.blank?

      account_number.gsub(/.(?=.{#{all_but}})/, char)
    end
  end
end
