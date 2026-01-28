# frozen_string_literal: true

module Lighthouse
  module HCC
    class CopayDetail
      include Vets::Model

      PAYMENT_DUE_DAYS = 30

      attribute :external_id, String
      attribute :facility, Hash
      attribute :bill_number, String
      attribute :status, String
      attribute :status_description, String
      attribute :invoice_date, String
      attribute :payment_due_date, String
      attribute :account_number, String

      attribute :original_amount, Float
      attribute :principal_balance, Float
      attribute :interest_balance, Float
      attribute :administrative_cost_balance, Float
      attribute :principal_paid, Float
      attribute :interest_paid, Float
      attribute :administrative_cost_paid, Float

      attribute :line_items, Hash, array: true
      attribute :payments, Hash, array: true

      def initialize(attrs = {})
        @invoice_data = attrs[:invoice_data]
        @account_data = attrs[:account_data]
        @charge_items = attrs[:charge_items] || {}
        @encounters = attrs[:encounters] || {}
        @medication_dispenses = attrs[:medication_dispenses] || {}
        @medications = attrs[:medications] || {}
        @payments_data = attrs[:payments] || []
        @facility_address = attrs[:facility_address]
        assign_attributes
      end

      private

      def assign_attributes
        @external_id = @invoice_data['id']
        @bill_number = @invoice_data.dig('identifier', 0, 'value')
        @status = @invoice_data['status']
        @status_description = @invoice_data.dig('_status', 'valueCodeableConcept', 'text')
        @invoice_date = @invoice_data['date']
        @payment_due_date = calculate_payment_due_date
        @account_number = @account_data&.dig('identifier', 0, 'value')

        assign_balances
        assign_line_items
        assign_payments
        assign_facility
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

      def assign_line_items
        invoice_line_items = @invoice_data['lineItem'] || []
        @line_items = invoice_line_items.map { |li| build_line_item(li) }
      end

      def assign_facility
        @facility = {
          'name' => @invoice_data.dig('issuer', 'display'),
          'address' => build_facility_address
        }
      end

      def build_facility_address
        return nil unless @facility_address

        {
          'address_line1' => @facility_address[:address_line1],
          'address_line2' => @facility_address[:address_line2],
          'address_line3' => @facility_address[:address_line3],
          'city' => @facility_address[:city],
          'state' => @facility_address[:state],
          'postalCode' => @facility_address[:postalCode]
        }
      end

      def build_line_item(invoice_line_item)
        charge_item_id = extract_id_from_reference(invoice_line_item.dig('chargeItemReference', 'reference'))
        charge_item = @charge_items[charge_item_id] || {}

        {
          billing_reference: charge_item_id,
          date_posted: extract_date_posted(charge_item),
          description: charge_item.dig('code', 'text'),
          provider_name: extract_provider_name(charge_item),
          price_components: build_price_components(invoice_line_item),
          medication: build_medication(charge_item)
        }.compact
      end

      def extract_date_posted(charge_item)
        charge_item['occurrenceDateTime'] ||
          charge_item.dig('occurrencePeriod', 'start') ||
          charge_item['enteredDate']
      end

      def extract_provider_name(charge_item)
        encounter_ref = charge_item.dig('context', 'reference')
        return nil unless encounter_ref

        encounter_id = extract_id_from_reference(encounter_ref)
        encounter = @encounters[encounter_id]
        encounter&.dig('serviceProvider', 'display')
      end

      def build_price_components(invoice_line_item)
        components = invoice_line_item['priceComponent'] || []
        components.map do |pc|
          {
            type: pc['type'],
            code: pc.dig('code', 'text'),
            amount: pc.dig('amount', 'value')&.to_f
          }
        end
      end

      def build_medication(charge_item)
        services = charge_item['service'] || []
        dispense_ref = services.find { |s| s['reference']&.include?('MedicationDispense') }&.dig('reference')
        return nil unless dispense_ref

        dispense_id = extract_id_from_reference(dispense_ref)
        dispense = @medication_dispenses[dispense_id]
        return nil unless dispense

        medication_ref = dispense.dig('medicationReference', 'reference')
        medication_id = extract_id_from_reference(medication_ref)
        medication = @medications[medication_id]

        {
          medication_name: dispense.dig('medicationReference', 'display') ||
            dispense.dig('medicationCodeableConcept', 'text'),
          rx_number: medication&.dig('identifier', 0, 'id'),
          quantity: dispense.dig('quantity', 'value'),
          days_supply: dispense.dig('daysSupply', 'value')
        }
      end

      def assign_payments
        @payments = @payments_data.map { |p| build_payment(p) }
      end

      def build_payment(payment_data)
        {
          payment_id: payment_data['id'],
          payment_date: payment_data['paymentDate'],
          payment_amount: payment_data.dig('paymentAmount', 'value')&.to_f,
          transaction_number: extract_transaction_number(payment_data),
          bill_number: extract_bill_number(payment_data),
          invoice_reference: extract_invoice_reference(payment_data),
          disposition: payment_data['disposition'],
          detail: build_payment_detail(payment_data)
        }
      end

      def extract_transaction_number(payment_data)
        identifiers = payment_data['identifier'] || []
        identifiers.find { |i| i.dig('type', 'text') == 'Transaction Number' }&.dig('value')
      end

      def extract_bill_number(payment_data)
        identifiers = payment_data['identifier'] || []
        identifiers.find { |i| i.dig('type', 'text') == 'Bill Number' }&.dig('value')
      end

      def extract_invoice_reference(payment_data)
        extensions = payment_data['extension'] || []
        target_ext = extensions.find { |e| e['url']&.include?('allocation.target') }
        return nil unless target_ext

        extract_id_from_reference(target_ext.dig('valueReference', 'reference'))
      end

      def build_payment_detail(payment_data)
        details = payment_data['detail'] || []
        details.map do |d|
          {
            type: d.dig('type', 'text'),
            amount: d.dig('amount', 'value')&.to_f
          }
        end
      end

      def find_amount(components, code_text)
        components.find { |c| c.dig('code', 'text') == code_text }&.dig('amount', 'value')&.to_f
      end

      def calculate_payment_due_date
        return nil unless @invoice_date

        (Date.parse(@invoice_date) + PAYMENT_DUE_DAYS.days).iso8601
      rescue Date::Error
        nil
      end

      def extract_id_from_reference(reference)
        return nil unless reference

        reference.split('/').last
      end
    end
  end
end
