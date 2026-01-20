# frozen_string_literal: true

module Lighthouse
  module HCC
    class CopayDetailSerializer
      include JSONAPI::Serializer

      set_key_transform :camel_lower
      set_type :medical_copay_details
      set_id :external_id

      attributes :external_id,
                 :facility,
                 :bill_number,
                 :status,
                 :status_description,
                 :invoice_date,
                 :payment_due_date,
                 :account_number,
                 :facility_address1,
                 :facility_address2,
                 :facility_address3,
                 :facility_city,
                 :facility_state,
                 :facility_zip,
                 :original_amount,
                 :principal_balance,
                 :interest_balance,
                 :administrative_cost_balance,
                 :principal_paid,
                 :interest_paid,
                 :administrative_cost_paid,
                 :line_items,
                 :payments

      meta do |object|
        {
          line_item_count: object.line_items.size,
          payment_count: object.payments.size
        }
      end
    end
  end
end
