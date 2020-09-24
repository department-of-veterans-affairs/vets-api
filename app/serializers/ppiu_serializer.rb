# frozen_string_literal: true

class PPIUSerializer < ActiveModel::Serializer
  attribute :responses

  def responses
    object.responses.each do |response|
      account_number = response.payment_account&.account_number
      response.payment_account.account_number = mask(account_number) if account_number
      routing_number = response.payment_account&.financial_institution_routing_number
      response.payment_account.financial_institution_routing_number = mask(routing_number) if routing_number
    end
  end

  def mask(number)
    number.gsub(/.(?=.{4})/, '*')
  end

  def id
    nil
  end
end
