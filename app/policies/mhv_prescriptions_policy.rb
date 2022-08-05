# frozen_string_literal: true

MHVPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCOUNT_TYPES = %w[Premium Advanced].freeze

  # NOTE: This check for va_patient, might break functionality for mhv-sign-in users,
  # since we only query MVI for "Premium", and Rx is technically available to non-premium.
  def access?
    service_name = user.identity.sign_in[:service_name]
    RX_ACCOUNT_TYPES.include?(user.mhv_account_type) && (user.va_patient? || service_name == 'mhv')
  end
end
