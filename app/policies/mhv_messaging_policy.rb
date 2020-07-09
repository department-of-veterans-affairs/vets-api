# frozen_string_literal: true

MhvMessagingPolicy = Struct.new(:user, :mhv_messaging) do
  SM_ACCOUNT_TYPES = %w[Premium].freeze

  def access?
    SM_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
  end
end
