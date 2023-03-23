# frozen_string_literal: true

require 'sign_in/logingov/service'
require 'sign_in/idme/service'
require 'credential/service'

module SignIn
  class AuthenticationServiceRetriever
    attr_reader :type, :client_config

    def initialize(type:, client_config: nil)
      @type = type
      @client_config = client_config
    end

    def perform
      if client_config&.mock_auth?
        mock_auth_service
      else
        auth_service
      end
    end

    private

    def auth_service
      case type
      when Constants::Auth::LOGINGOV
        logingov_auth_service
      else
        idme_auth_service
      end
    end

    def idme_auth_service
      @idme_auth_service ||= begin
        @idme_auth_service = Idme::Service.new
        @idme_auth_service.type = type
        @idme_auth_service
      end
    end

    def logingov_auth_service
      @logingov_auth_service ||= Logingov::Service.new
    end

    def mock_auth_service
      @mock_auth_service ||= begin
        @mock_auth_service = MockedAuthentication::Credential::Service.new
        @mock_auth_service.type = type
        @mock_auth_service
      end
    end
  end
end
