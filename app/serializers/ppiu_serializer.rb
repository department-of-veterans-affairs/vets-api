# frozen_string_literal: true

class PPIUSerializer < ActiveModel::Serializer
  attribute :responses

  def responses
    object.responses.each do |response|
      account_number = response.payment_account&.account_number
      response.payment_account.account_number = StringHelpers.mask_sensitive(account_number) if account_number
      routing_number = response.payment_account&.financial_institution_routing_number
      if routing_number
        response.payment_account.financial_institution_routing_number = StringHelpers.mask_sensitive(routing_number)
      end
    end
  end

  def id
    nil
  end
end
