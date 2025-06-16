# frozen_string_literal: true

require 'rx/client'

MHVPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCOUNT_TYPES = %w[Premium Advanced].freeze

  def access?
    if Flipper.enabled?(:update_mhv_prescriptions_policy)
      feature_flag_access_check
    else
      default_access_check
    end
  end

  private

  def feature_flag_access_check
    return false unless user.mhv_correlation_id && user.va_patient?

    begin
      client = Rx::Client.new(session: { user_id: user.mhv_correlation_id, user_uuid: user.uuid })
      handle_client_session(client)
    rescue
      log_access_denied('RX ACCESS DENIED (feature flag)')
      false
    end
  end

  def handle_client_session(client)
    if client.session.expired?
      client.authenticate
      !client.session.expired?
    else
      true
    end
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
