# frozen_string_literal: true

MHVMessagingPolicy = Struct.new(:user, :mhv_messaging) do
  SM_ACCOUNT_TYPES = %w[Premium].freeze

  def access?
  # SM_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient? # DO NOT MERGE: FOR LOCAL  DEV PURPOSES ONLY
    # false # BASIC User
    true # PREMIUM User
  end
end
