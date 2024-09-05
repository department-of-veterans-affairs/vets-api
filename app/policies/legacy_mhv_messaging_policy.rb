# frozen_string_literal: true

# TODO: migrate all services off this policy and onto the new one.
LegacyMHVMessagingPolicy = Struct.new(:user, :legacy_mhv_messaging) do
  SM_ACCOUNT_TYPES = %w[Premium].freeze
  def access?
    SM_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
  end
end
