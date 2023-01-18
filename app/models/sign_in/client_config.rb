# frozen_string_literal: true

module SignIn
  class ClientConfig
    include ActiveModel::Validations
    attr_reader :client_id

    validates :client_id, presence: true, inclusion: { in: SignIn::Constants::Auth::CLIENT_IDS }

    def initialize(client_id:)
      @client_id = client_id
      validate!
    end

    def cookie_auth?
      client_config[:cookie_auth]
    end

    def api_auth?
      client_config[:api_auth]
    end

    def anti_csrf?
      client_config[:anti_csrf]
    end

    def redirect_uri
      client_config[:redirect_uri]
    end

    def access_token_duration
      client_config[:access_token_duration]
    end

    def access_token_audience
      client_config[:access_token_audience]
    end

    def refresh_token_duration
      client_config[:refresh_token_duration]
    end

    private

    def client_config
      @client_config ||=
        case @client_id
        when SignIn::Constants::Auth::WEB_CLIENT, SignIn::Constants::Auth::VA_WEB_CLIENT
          web_config
        when SignIn::Constants::Auth::MOBILE_CLIENT, SignIn::Constants::Auth::VA_MOBILE_CLIENT
          mobile_config
        when SignIn::Constants::Auth::MOBILE_TEST_CLIENT
          mobile_test_config
        end
    end

    def web_config
      {
        cookie_auth: true,
        api_auth: false,
        anti_csrf: true,
        redirect_uri: Settings.sign_in.client_redirect_uris.web,
        access_token_duration: Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES.minutes,
        access_token_audience: 'va.gov',
        refresh_token_duration: Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES.minutes
      }
    end

    def mobile_config
      {
        cookie_auth: false,
        api_auth: true,
        anti_csrf: false,
        redirect_uri: Settings.sign_in.client_redirect_uris.mobile,
        access_token_duration: Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES.minutes,
        access_token_audience: 'vamobile',
        refresh_token_duration: Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS.days
      }
    end

    def mobile_test_config
      {
        cookie_auth: false,
        api_auth: true,
        anti_csrf: false,
        redirect_uri: Settings.sign_in.client_redirect_uris.mobile_test,
        access_token_duration: Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES.minutes,
        access_token_audience: 'vamobile',
        refresh_token_duration: Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS.days
      }
    end
  end
end
