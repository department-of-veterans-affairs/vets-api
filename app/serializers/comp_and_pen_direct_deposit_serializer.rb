# frozen_string_literal: true

class CompAndPenDirectDepositSerializer < ActiveModel::Serializer
  attributes :control_information, :payment_account, :error

  def control_information
    object[:control_information]
  end

  def payment_account
    return unless object[:payment_account]

    payment_account = object[:payment_account]

    account_number = payment_account&.account_number
    payment_account.account_number = StringHelpers.mask_sensitive(account_number) if account_number

    routing_number = payment_account&.routing_number
    payment_account.routing_number = StringHelpers.mask_sensitive(routing_number) if routing_number

    payment_account
  end

  def error
    object[:error]
  end

  def id
    nil
  end
end
