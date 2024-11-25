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

    def initialize(session:,
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
      {
        user_uuid: access_token.to_s[:user_uuid],
        session_handle: session.handle,
        client_id: session.client_id,
        type: session.user_verification.credential_type,
        icn: session.user_account.icn
      }
    end
  end
end
