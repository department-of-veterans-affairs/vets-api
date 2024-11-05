# frozen_string_literal: true

class PPIUSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :evss_ppiu_payment_information_responses

  attribute :responses do |object|
    object.responses.each do |response|
      account_number = response.payment_account&.account_number
      response.payment_account.account_number = StringHelpers.mask_sensitive(account_number) if account_number
      routing_number = response.payment_account&.financial_institution_routing_number
      if routing_number
        response.payment_account.financial_institution_routing_number = StringHelpers.mask_sensitive(routing_number)
      end
    end
  end
end
