# frozen_string_literal: true

module Lighthouse
  module HCC
    class CopayDetailSerializer
      include JSONAPI::Serializer

      set_type :medical_copay_details
      set_key_transform :camel_lower
      set_id :external_id

      attributes :external_id,
                 :facility,
                 :bill_number,
                 :status,
                 :status_description,
                 :invoice_date,
                 :payment_due_date,
                 :account_number,
                 :original_amount,
                 :principal_balance,
                 :interest_balance,
                 :administrative_cost_balance,
                 :principal_paid,
                 :interest_paid,
                 :administrative_cost_paid

      attribute :line_items do |object|
        object.line_items.map { |li| transform_line_item(li) }
      end

      attribute :payments do |object|
        object.payments.map { |p| transform_payment(p) }
      end

      class << self
        def transform_line_item(line_item)
          result = {
            billingReference: line_item[:billing_reference],
            datePosted: line_item[:date_posted],
            description: line_item[:description],
            providerName: line_item[:provider_name],
            priceComponents: transform_price_components(line_item[:price_components])
          }
          result[:medication] = transform_medication(line_item[:medication]) if line_item[:medication]
          result
        end

        def transform_price_components(components)
          return [] unless components

          components.map do |pc|
            { type: pc[:type], code: pc[:code], amount: pc[:amount] }
          end
        end

        def transform_medication(medication)
          return nil unless medication

          {
            medicationName: medication[:medication_name],
            rxNumber: medication[:rx_number],
            quantity: medication[:quantity],
            daysSupply: medication[:days_supply]
          }
        end

        def transform_payment(payment)
          {
            paymentId: payment[:payment_id],
            paymentDate: payment[:payment_date],
            paymentAmount: payment[:payment_amount],
            transactionNumber: payment[:transaction_number],
            billNumber: payment[:bill_number],
            invoiceReference: payment[:invoice_reference],
            disposition: payment[:disposition],
            detail: transform_payment_detail(payment[:detail])
          }
        end

        def transform_payment_detail(detail)
          return [] unless detail

          detail.map { |d| { type: d[:type], amount: d[:amount] } }
        end
      end

      meta do |object|
        {
          lineItemCount: object.line_items.size,
          paymentCount: object.payments.size
        }
      end
    end
  end
end
