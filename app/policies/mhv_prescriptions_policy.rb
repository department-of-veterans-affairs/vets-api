# frozen_string_literal: true

require 'rx/client'

MHVPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCESS_LOG_MESSAGE = 'RX ACCESS DENIED'

  def access?
    unless user.mhv_correlation_id
      log_access_denied(RX_ACCESS_LOG_MESSAGE)
      return false
    end

    return true if user.loa3? && (mhv_user_account&.patient || mhv_user_account&.champ_va)

    log_access_denied(RX_ACCESS_LOG_MESSAGE)
    false
  end

  private

  def mhv_user_account
    user.mhv_user_account(from_cache_only: false)
  end

  def log_access_denied(message)
    Rails.logger.info(message,
                      mhv_id: user.mhv_correlation_id.presence || 'false',
                      sign_in_service: user.identity.sign_in[:service_name],
                      va_facilities: user.va_treatment_facility_ids.length,
                      va_patient: user.va_patient?)
  end
end
