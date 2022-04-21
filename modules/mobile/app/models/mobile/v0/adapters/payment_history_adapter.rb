# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class PaymentHistoryAdapter < ::Adapters::PaymentHistoryAdapter
        private

        def process_payments(payments)
          # filter out future scheduled payments
          past_payments = payments.reject { |payment| payment[:payment_date].nil? }

          past_payments.map do |payment|
            Mobile::V0::PaymentHistory.new(
              id: payment.dig(:payment_record_identifier, :payment_id),
              account: mask_account_number(payment[:address_eft]),
              amount: ActiveSupport::NumberHelper.number_to_currency(payment[:payment_amount]),
              bank: payment.dig(:address_eft, :bank_name),
              date: payment[:payment_date],
              payment_method: get_payment_method(payment),
              payment_type: payment[:payment_type]
            )
          end
        end
      end
    end
  end
end
