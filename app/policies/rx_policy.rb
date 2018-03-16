# frozen_string_literal: true

RxPolicy = Struct.new(:user, :mhv_prescriptions) do
  ACCOUNT_TYPES = %w[Premium Advanced]

  def access?
    ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
  end
end
