# frozen_string_literal: true

require 'common/client/configuration/rest'

module VAProfile
  module Profile
    module V3
      ##
      # HTTP client configuration for the {VAProfile::Profile::V3::Service},
      # sets the base path, the base request headers, and a service name for breakers and metrics.
      #
      class Configuration < Common::Client::Configuration::REST
        self.read_timeout = VAProfile::Configuration::SETTINGS.military_personnel.timeout || 30

        PROFILE_V3_PATH = 'profile-service/profile/v3'

        ##
        # @return [String] Base path for direct_deposit URLs.
        #
        def base_path
          "#{VAProfile::Configuration::SETTINGS.url}/#{PROFILE_V3_PATH}"
        end

        ##
        # @return [String] Service name to use in breakers and metrics.
        #
        def service_name
          'VAPROFILE_PROFILE_V3'
        end

        ##
        # @return [Faraday::Response] response from POST request
        #
        def post(path, body = {})
          connection.post(path, body)
        end

        alias submit post

        ##
        # Creates a Faraday connection with parsing json and breakers functionality.
        #
        # @return [Faraday::Connection] a Faraday connection instance.
        #
        def connection
          @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
            faraday.use(:breakers, service_name:)
            faraday.request :json

            faraday.response :betamocks if use_mocks?
            faraday.response :snakecase, symbolize: false
            faraday.response :json, content_type: /\bjson/

            faraday.adapter Faraday.default_adapter
          end
        end

        private

        ##
        # @return [Boolean] Should the service use mock data in lower environments.
        #
        def use_mocks?
          VAProfile::Configuration::SETTINGS.military_personnel.use_mocks || false
        end
      end
    end
  end
end
