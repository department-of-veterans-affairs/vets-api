# frozen_string_literal: true

require 'rx/client'

MHVPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCOUNT_TYPES = %w[Premium Advanced].freeze

  def access?
    if Flipper.enabled?(:mhv_medications_new_policy, user)
      user.loa3? && (mhv_user_account&.patient || mhv_user_account&.champ_va)
    else
      default_access_check
    end
  end

  private

  def mhv_user_account
    user.mhv_user_account(from_cache_only: false)
  end

  def default_access_check
    service_name = user.identity.sign_in[:service_name]
    access = RX_ACCOUNT_TYPES.include?(user.mhv_account_type) &&
             (user.va_patient? || service_name == SignIn::Constants::Auth::MHV)
    log_access_denied('RX ACCESS DENIED') unless access
    access
  end

  def log_access_denied(message)
    Rails.logger.info(message,
                      mhv_id: user.mhv_correlation_id.presence || 'false',
                      sign_in_service: user.identity.sign_in[:service_name],
                      va_facilities: user.va_treatment_facility_ids.length,
                      va_patient: user.va_patient?)
  end
end
