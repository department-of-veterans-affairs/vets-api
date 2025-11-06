# frozen_string_literal: true

class Lighthouse::HealthcareCostAndCoverage::InvoiceSerializer
  include JSONAPI::Serializer

  set_key_transform :camel_lower

  attribute :id
  attribute :url
  attribute :facility
  attribute :external_id
  attribute :billing_ref
  attribute :current_balance
  attribute :previous_balance
  attribute :previous_unpaid_balance
end
