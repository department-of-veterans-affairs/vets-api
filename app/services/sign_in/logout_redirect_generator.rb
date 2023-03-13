# frozen_string_literal: true

require 'sign_in/logingov/service'

module SignIn
  class LogoutRedirectGenerator
    attr_reader :user, :client_config

    def initialize(user:, client_config:)
      @user = user
      @client_config = client_config
    end

    def perform
      return unless logout_redirect_uri

      if authenticated_with_logingov?
        logingov_service.render_logout(encode_logout_redirect)
      else
        parse_logout_redirect_uri
      end
    end

    private

    def parse_logout_redirect_uri
      URI.parse(logout_redirect_uri).to_s
    end

    def authenticated_with_logingov?
      authenticated_credential == Constants::Auth::LOGINGOV
    end

    def encode_logout_redirect
      Base64.encode64(generate_logout_state_payload.to_s)
    end

    def generate_logout_state_payload
      {
        logout_redirect: logout_redirect_uri,
        seed: random_seed
      }
    end

    def logout_redirect_uri
      @logout_redirect_uri ||= client_config.logout_redirect_uri
    end

    def authenticated_credential
      @authenticated_credential ||= user.nil? ? nil : user.identity.sign_in[:service_name]
    end

    def random_seed
      @random_seed ||= SecureRandom.hex
    end

    def logingov_service
      @logingov_service ||= SignIn::Logingov::Service.new
    end
  end
end
