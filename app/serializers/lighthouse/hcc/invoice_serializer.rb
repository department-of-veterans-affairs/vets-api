# frozen_string_literal: true

class Lighthouse::HealthcareCostAndCoverage::InvoiceSerializer
  include JSONAPI::Serializer

  set_type :invoice
  set_key_transform :camel_lower
  set_id :external_id

  attributes :url,
             :facility,
             :external_id,
             :billing_ref,
             :current_balance,
             :previous_balance,
             :previous_unpaid_balance
end
