# frozen_string_literal: true

MHVPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCOUNT_TYPES = %w[Premium Advanced].freeze

  # NOTE: This check for va_patient, might break functionality for mhv-sign-in users,
  # since we only query MVI for "Premium", and Rx is technically available to non-premium.
  def access?
    service_name = user.identity.sign_in[:service_name]
    access = RX_ACCOUNT_TYPES.include?(user.mhv_account_type) &&
             (user.va_patient? || service_name == SignIn::Constants::Auth::MHV)
    unless access
      Rails.logger.info('RX ACCESS DENIED',
                        account_type: user.mhv_account_type.presence || 'false',
                        mhv_id: user.mhv_correlation_id.presence || 'false',
                        sign_in_service: service_name,
                        va_facilities: user.va_treatment_facility_ids.length,
                        va_patient: user.va_patient?)
    end
    access
  end
end
