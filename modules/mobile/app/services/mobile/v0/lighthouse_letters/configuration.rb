# frozen_string_literal: true

module Mobile
  module V0
    module LighthouseLetters
      # Configuration for the Mobile::V0::LighthouseLetters::Service
      #
      class Configuration < Common::Client::Configuration::REST
        # Service name for breakers integration
        #
        # @return String the service name
        #
        def service_name
          'MobileLighthouseLetters'
        end

        # The URL to use when fetching an access_token when creating a new
        # session on behalf of a veteran.
        #
        # @return String the access token URL
        #
        def access_token_url
          Settings.mobile_lighthouse_letters.access_token_url
        end

        # The base URL to use when querying the Health FHIR API
        #
        # @return String the base URL
        #
        def api_url
          Settings.mobile_lighthouse_letters.api_url
        end

        # Distinct Faraday connection for hitting the access token endpoint
        #
        # @return Faraday::Connection a Faraday connection instance with the correct middleware
        #
        def access_token_connection
          Faraday.new(access_token_url, headers:) do |conn|
            conn.use :breakers
            conn.response :json, content_type: /\bjson$/
            conn.adapter Faraday.default_adapter
          end
        end

        def headers
          {
            'Host' => 'sandbox-api.va.gov',
            'Content-Type' => 'application/x-www-form-urlencoded'
          }
        end

        # Main connection for querying the Health FHIR API
        #
        # @return Faraday::Connection a Faraday connection instance with the correct middleware
        #
        def connection
          Faraday.new(api_url) do |conn|
            conn.use :breakers
            conn.response :snakecase
            conn.response :json, content_type: /\bjson$/
            conn.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
