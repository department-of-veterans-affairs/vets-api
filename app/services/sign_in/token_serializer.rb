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
      else
        raise Errors::InvalidClientIdError, 'Client id is not valid'
      end
    end

    private

    def set_cookies
      set_cookie!(name: Constants::Auth::ACCESS_TOKEN_COOKIE_NAME,
                  value: encoded_access_token,
                  expires: access_token_expiration)
      set_cookie!(name: Constants::Auth::REFRESH_TOKEN_COOKIE_NAME,
                  value: encrypted_refresh_token,
                  path: Constants::Auth::REFRESH_ROUTE_PATH,
                  expires: refresh_token_expiration)
      if anti_csrf_enabled_client?
        set_cookie!(name: Constants::Auth::ANTI_CSRF_COOKIE_NAME,
                    value: anti_csrf_token,
                    expires: refresh_token_expiration)
      end
    end

    # rubocop:disable Metrics/ParameterLists
    def set_cookie!(name:, value:, expires:, path: '/', secure: Settings.sign_in.cookies_secure, httponly: true)
      cookies[name] = {
        value: value,
        expires: expires,
        path: path,
        secure: secure,
        httponly: httponly
      }
    end
    # rubocop:enable Metrics/ParameterLists

    def set_info_cookie
      set_cookie!(name: Constants::Auth::INFO_COOKIE_NAME,
                  value: info_cookie_value,
                  expires: refresh_token_expiration,
                  httponly: false,
                  secure: false)
    end

    def info_cookie_value
      {
        access_token_expiration: access_token_expiration,
        refresh_token_expiration: refresh_token_expiration
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

    def refresh_token_expiration
      @refresh_token_expiration ||= session_container.session.refresh_expiration
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

    def client_id
      @client_id ||= session_container.client_id
    end
  end
end
