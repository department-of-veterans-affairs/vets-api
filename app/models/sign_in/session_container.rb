# frozen_string_literal: true

module SignIn
  class SessionContainer
    include ActiveModel::Validations

    attr_reader(
      :session,
      :refresh_token,
      :access_token,
      :anti_csrf_token,
      :client_config,
      :device_secret
    )

    validates(
      :session,
      :refresh_token,
      :access_token,
      :anti_csrf_token,
      :client_config,
      presence: true
    )

    def initialize(session:, # rubocop:disable Metrics/ParameterLists
                   refresh_token:,
                   access_token:,
                   anti_csrf_token:,
                   client_config:,
                   device_secret: nil)
      @session = session
      @refresh_token = refresh_token
      @access_token = access_token
      @anti_csrf_token = anti_csrf_token
      @client_config = client_config
      @device_secret = device_secret

      validate!
    end

    def persisted?
      false
    end

    def context
      access_token_attributes = access_token.to_s
      {
        access_token_uuid: access_token_attributes[:uuid],
        user_uuid: access_token_attributes[:user_uuid],
        session_handle: session.handle,
        client_id: session.client_id,
        access_token_audience: access_token_attributes[:audience],
        version: access_token_attributes[:version],
        last_regeneration_time: access_token_attributes[:last_regeneration_time],
        access_token_created_time: access_token_attributes[:created_time],
        access_token_expiration_time: access_token_attributes[:expiration_time],
        type: session.user_verification.credential_type,
        icn: session.user_account.icn
      }
    end
  end
end
