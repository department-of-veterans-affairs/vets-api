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
        set_info_cookie
        {}
      elsif api_authentication_client?
        token_json_response
      elsif mock_authentication_client?
        set_cookies
        set_info_cookie
        token_json_response
      end
    end

    private

    def set_cookies
      set_cookie!(name: Constants::Auth::REFRESH_TOKEN_COOKIE_NAME,
                  value: encrypted_refresh_token,
                  path: Constants::Auth::REFRESH_ROUTE_PATH,
                  expires: session_expiration)
      set_cookie!(name: Constants::Auth::ACCESS_TOKEN_COOKIE_NAME,
                  value: encoded_access_token,
                  expires: session_expiration)
      if anti_csrf_enabled_client?
        set_cookie!(name: Constants::Auth::ANTI_CSRF_COOKIE_NAME,
                    value: anti_csrf_token,
                    expires: session_expiration)
      end
    end

    def set_cookie!(name:, value:, expires:, path: '/')
      cookies[name] = {
        value: value,
        expires: expires,
        path: path,
        secure: Settings.sign_in.cookies_secure,
        httponly: true
      }
    end

    def set_info_cookie
      cookies[Constants::Auth::INFO_COOKIE_NAME] = {
        value: info_cookie_value,
        expires: session_expiration,
        secure: Settings.sign_in.cookies_secure,
        httponly: false,
        domain: Settings.sign_in.info_cookie_domain
      }
    end

    def info_cookie_value
      {
        access_token_expiration: access_token_expiration,
        refresh_token_expiration: session_expiration
      }
    end

    def token_json_response
      { data: token_json_payload }
    end

    def token_json_payload
      payload = {}
      payload[:refresh_token] = encrypted_refresh_token
      payload[:access_token] = encoded_access_token
      payload[:anti_csrf_token] = anti_csrf_token if anti_csrf_enabled_client?
      payload
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
  end
end
