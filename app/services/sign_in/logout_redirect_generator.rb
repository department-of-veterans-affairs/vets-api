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
        logingov_service.render_logout(logout_redirect_uri)
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

    def logout_redirect_uri
      @logout_redirect_uri ||= client_config.logout_redirect_uri
    end

    def authenticated_credential
      @authenticated_credential ||= user.nil? ? nil : user.identity.sign_in[:service_name]
    end

    def logingov_service
      AuthenticationServiceRetriever.new(type: Constants::Auth::LOGINGOV).perform
    end
  end
end
