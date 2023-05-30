# frozen_string_literal: true

class DisabilityCompensationsSerializer < ActiveModel::Serializer
  attributes :control_information, :payment_account

  def control_information
    object[:control_information]
  end

  def payment_account
    return unless object.key?(:payment_account)

    payment_account = object[:payment_account]

    account_number = payment_account&.dig(:account_number)
    payment_account[:account_number] = StringHelpers.mask_sensitive(account_number) if account_number

    routing_number = payment_account&.dig(:routing_number)
    payment_account[:routing_number] = StringHelpers.mask_sensitive(routing_number) if routing_number

    payment_account
  end

  def id
    nil
  end

  def type
    'direct_deposit/disability_compensations'
  end
end
