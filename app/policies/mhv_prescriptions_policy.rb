# frozen_string_literal: true

MhvPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCOUNT_TYPES = %w[Premium Advanced].freeze

  # NOTE: This check for va_patient, might break functionality for mhv-sign-in users,
  # since we only query MVI for "Premium", and Rx is technically available to non-premium.
  def access?
    RX_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
  end
end
