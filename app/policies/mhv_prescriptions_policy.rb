# frozen_string_literal: true

MhvPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCOUNT_TYPES = %w[Premium Advanced].freeze

  def access?
    RX_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
  end
end
