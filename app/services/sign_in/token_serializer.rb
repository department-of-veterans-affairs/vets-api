# frozen_string_literal: true

module SignIn
  class TokenSerializer
    attr_reader :session_container, :cookies

    def initialize(session_container:, cookies:)
      @session_container = session_container
      @cookies = cookies
    end

    def perform
      if cookie_authentication_client?
        set_cookies
        {}
      elsif api_authentication_client?
        token_json_response
      elsif mock_authentication_client?
        set_cookies
        token_json_response
      end
    end

    private

    def set_cookies
      set_cookie!(name: Constants::Auth::ACCESS_TOKEN_COOKIE_NAME,
                  value: encoded_access_token,
                  httponly: true,
                  domain: :all)

      set_cookie!(name: Constants::Auth::REFRESH_TOKEN_COOKIE_NAME,
                  value: encrypted_refresh_token,
                  httponly: true,
                  path: Constants::Auth::REFRESH_ROUTE_PATH)

      set_cookie!(name: Constants::Auth::INFO_COOKIE_NAME,
                  value: info_cookie_value.to_json,
                  httponly: false,
                  domain: IdentitySettings.sign_in.info_cookie_domain)

      if anti_csrf_enabled_client?
        set_cookie!(name: Constants::Auth::ANTI_CSRF_COOKIE_NAME,
                    value: anti_csrf_token,
                    httponly: true)
      end
    end

    def set_cookie!(name:, value:, httponly:, domain: nil, path: '/')
      cookies[name] = {
        value:,
        expires: session_expiration,
        secure: IdentitySettings.sign_in.cookies_secure,
        httponly:,
        path:,
        domain:
      }.compact
    end

    def info_cookie_value
      {
        access_token_expiration:,
        refresh_token_expiration: session_expiration
      }
    end

    def token_json_response
      return { data: token_json_payload } if json_api_compatibility_client?

      token_json_payload
    end

    def token_json_payload
      payload = {}
      payload[:refresh_token] = encrypted_refresh_token unless web_sso_client?
      payload[:access_token] = encoded_access_token
      payload[:anti_csrf_token] = anti_csrf_token if anti_csrf_enabled_client?
      payload[:device_secret] = device_secret if device_secret_enabled_client?
      payload
    end

    def device_secret_enabled_client?
      api_authentication_client? && client_config.shared_sessions && device_secret
    end

    def cookie_authentication_client?
      client_config.cookie_auth?
    end

    def api_authentication_client?
      client_config.api_auth?
    end

    def mock_authentication_client?
      client_config.mock_auth?
    end

    def anti_csrf_enabled_client?
      client_config.anti_csrf
    end

    def json_api_compatibility_client?
      client_config.json_api_compatibility
    end

    def device_secret
      @device_secret ||= session_container.device_secret
    end

    def session_expiration
      @session_expiration ||= session_container.session.refresh_expiration
    end

    def access_token_expiration
      @access_token_expiration ||= session_container.access_token.expiration_time
    end

    def encrypted_refresh_token
      @encrypted_refresh_token ||=
        RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
    end

    def encoded_access_token
      @encoded_access_token ||= AccessTokenJwtEncoder.new(access_token: session_container.access_token).perform
    end

    def anti_csrf_token
      @anti_csrf_token ||= session_container.anti_csrf_token
    end

    def client_config
      @client_config ||= session_container.client_config
    end

    def web_sso_client?
      @web_sso_client ||= session_container.web_sso_client
    end
  end
end
