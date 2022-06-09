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
      else
        raise Errors::InvalidClientIdError, 'Client id is not valid'
      end
    end

    private

    def set_cookies
      set_cookie!(Constants::Auth::ACCESS_TOKEN_COOKIE_NAME, encoded_access_token)
      set_cookie!(Constants::Auth::REFRESH_TOKEN_COOKIE_NAME,
                  encrypted_refresh_token,
                  Constants::Auth::REFRESH_ROUTE_PATH)
      set_cookie!(Constants::Auth::ANTI_CSRF_COOKIE_NAME, anti_csrf_token) if anti_csrf_enabled_client?
    end

    def set_cookie!(name, token, path = '/')
      cookies[name] = {
        value: token,
        expires: nil,
        path: path,
        secure: Settings.sign_in.cookies_secure,
        httponly: true
      }
    end

    def token_json_response
      { data: token_json_payload }
    end

    def token_json_payload
      payload = {}
      payload[:access_token] = encoded_access_token
      payload[:refresh_token] = encrypted_refresh_token
      payload[:anti_csrf_token] = anti_csrf_token if anti_csrf_enabled_client?
      payload
    end

    def cookie_authentication_client?
      Constants::ClientConfig::COOKIE_AUTH.include?(client_id)
    end

    def api_authentication_client?
      Constants::ClientConfig::API_AUTH.include?(client_id)
    end

    def anti_csrf_enabled_client?
      Constants::ClientConfig::ANTI_CSRF_ENABLED.include?(client_id)
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

    def client_id
      @client_id ||= session_container.client_id
    end
  end
end
