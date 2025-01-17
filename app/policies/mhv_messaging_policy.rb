# frozen_string_literal: true

require 'sm/client'

MHVMessagingPolicy = Struct.new(:user, :mhv_messaging) do
  def access?
    Rails.logger.info('SM ACCESS ATTEMPT IN MOBILE POLICY with id: ', user.mhv_correlation_id)
    puts "SM ACCESS ATTEMPT IN MOBILE POLICY with id: #{user.mhv_correlation_id}"
    return false unless user.mhv_correlation_id

    client = SM::Client.new(session: { user_id: user.mhv_correlation_id })
    validate_client(client)
  end

  def mobile_access?
    return false unless user.mhv_correlation_id

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
