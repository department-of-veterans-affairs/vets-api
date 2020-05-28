# frozen_string_literal: true

require 'evss/configuration'

module EVSS
  module Dependents
    ##
    # HTTP client configuration for the {Dependents::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      ##
      # @return [String] Base path for dependents URLs.
      #
      def base_path
        "#{Settings.evss.url}/wss-686-services-web-2.6/rest/"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/Dependents'
      end

      ##
      # Creates the a connection with middleware for mapping errors, parsing json, and adding breakers functionality.
      #
      # @return [Faraday::Connection] a Faraday connection instance.
      #
      def connection
        @conn ||= Faraday.new(base_path, request: request_options, ssl: ssl_options) do |faraday|
          set_evss_middlewares(faraday, snakecase: false)
        end
      end
    end
  end
end
