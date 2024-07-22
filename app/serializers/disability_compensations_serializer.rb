# frozen_string_literal: true

class DisabilityCompensationsSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type 'direct_deposit/disability_compensations'

  attributes :control_information, :payment_account

  attribute :control_information do |object|
    object[:control_information]
  end

  attribute :payment_account do |object|
    next nil unless object.key?(:payment_account)

    payment_account = object[:payment_account]

    account_number = payment_account&.dig(:account_number)
    payment_account[:account_number] = StringHelpers.mask_sensitive(account_number) if account_number

    routing_number = payment_account&.dig(:routing_number)
    payment_account[:routing_number] = StringHelpers.mask_sensitive(routing_number) if routing_number

    payment_account
  end
end
