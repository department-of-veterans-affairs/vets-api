# frozen_string_literal: true

class Lighthouse::HCC::CopayDetailSerializer
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
             :original_amount,
             :principal_balance,
             :interest_balance,
             :administrative_cost_balance,
             :principal_paid,
             :interest_paid,
             :administrative_cost_paid
end
