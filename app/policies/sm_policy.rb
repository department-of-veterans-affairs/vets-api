# frozen_string_literal: true

SMPolicy = Struct.new(:user, :mhv_messaging) do
  ACCOUNT_TYPES = %w[Premium]

  def access?
    ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
  end
end
