# frozen_string_literal: true

require 'common/client/configuration/rest'

module Auth
  module ClientCredentials
    ##
    # HTTP client configuration for the {BenefitsClaims::Service},
    # sets the base path, the base request headers, and a service name for breakers and metrics.
    #
    class Configuration < Common::Client::Configuration::REST
      self.read_timeout = 20

      ##
      # @return [Hash] The basic headers required for any token service API call.
      #
      def self.base_request_headers
        super.merge({ 'Content-Type': 'application/x-www-form-urlencoded' })
      end

      ##
      # @return [Farday::Response] The response containing data needed to make further
      #   API calls.
      #
      def get_access_token(url, body)
        connection.post(url, URI.encode_www_form(body))
      end

      ##
      # Creates a Faraday connection with parsing json and adding breakers functionality.
      #
      # @return [Faraday::Connection] a Faraday connection instance.
      #
      def connection
        @conn ||= Faraday.new(headers: base_request_headers, request: request_options) do |faraday|
          faraday.use      :breakers
          faraday.use      Faraday::Response::RaiseError

          faraday.response :json
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
