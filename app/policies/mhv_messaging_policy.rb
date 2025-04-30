# frozen_string_literal: true

require 'sm/client'

MHVMessagingPolicy = Struct.new(:user, :mhv_messaging) do
  def access?
    return false unless user.mhv_correlation_id

    return false if Flipper.enabled?(:mhv_secure_messaging_policy_va_patient) && !user.va_patient?

    client = SM::Client.new(session: { user_id: user.mhv_correlation_id, user_uuid: user.uuid })
    validate_client(client)
  end

  def mobile_access?
    return false unless user.mhv_correlation_id && user.va_patient?

    client = Mobile::V0::Messaging::Client.new(session: { user_id: user.mhv_correlation_id })
    validate_client(client)
  end

  private

  def validate_client(client)
    if client.session.expired?
      client.authenticate
      !client.session.expired?
    else
      true
    end
  rescue
    log_denial_details
    false
  end

  def log_denial_details
    Rails.logger.info('SM ACCESS DENIED IN MOBILE POLICY',
                      mhv_id: user.mhv_correlation_id.presence || 'false',
                      sign_in_service: user.identity.sign_in[:service_name],
                      va_facilities: user.va_treatment_facility_ids.length,
                      va_patient: user.va_patient?)
  end
end
