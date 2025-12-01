# frozen_string_literal: true

module Lighthouse
  module HCC
    class CopayDetail
      include Vets::Model

      attribute :external_id, String
      attribute :facility, String
      attribute :bill_number, String
      attribute :status, String
      attribute :status_description, String
      attribute :invoice_date, String
      attribute :payment_due_date, String

      attribute :original_amount, Float
      attribute :principal_balance, Float
      attribute :interest_balance, Float
      attribute :administrative_cost_balance, Float
      attribute :principal_paid, Float
      attribute :interest_paid, Float
      attribute :administrative_cost_paid, Float

      def initialize(invoice_data)
        @invoice_data = invoice_data
        assign_attributes
      end

      private

      def assign_attributes
        @external_id = @invoice_data.dig('id')
        @facility = @invoice_data.dig('issuer', 'display')
        @bill_number = @invoice_data.dig('identifier', 0, 'value')
        @status = @invoice_data.dig('status')
        @status_description = @invoice_data.dig('_status', 'valueCodeableConcept', 'text')
        @invoice_date = @invoice_data.dig('date')
        @payment_due_date = calculate_payment_due_date

        assign_balances
      end

      def assign_balances
        total_price_components = @invoice_data['totalPriceComponent'] || []

        @original_amount = find_amount(total_price_components, 'Original Amount')
        @principal_balance = find_amount(total_price_components, 'Principal Balance')
        @interest_balance = find_amount(total_price_components, 'Interest Balance')
        @administrative_cost_balance = find_amount(total_price_components, 'Administrative Cost Balance')
        @principal_paid = find_amount(total_price_components, 'Principal Paid')
        @interest_paid = find_amount(total_price_components, 'Interest Paid')
        @administrative_cost_paid = find_amount(total_price_components, 'Administrative Cost Paid')
      end

      def find_amount(components, code_text)
        components.find { |c| c.dig('code', 'text') == code_text }&.dig('amount', 'value')&.to_f
      end

      def calculate_payment_due_date
        return nil unless @invoice_date

        (Date.parse(@invoice_date) + 30.days).iso8601
      rescue Date::Error
        nil
      end
    end
  end
end
