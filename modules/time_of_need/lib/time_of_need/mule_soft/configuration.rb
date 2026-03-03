# frozen_string_literal: true

require 'common/client/configuration/rest'

module TimeOfNeed
  module MuleSoft
    ##
    # Configuration for the TimeOfNeed MuleSoft client
    #
    # Reads settings from Settings.time_of_need.mulesoft
    #
    # TODO: Configure once we have:
    #   - MuleSoft endpoint URL
    #   - Timeout values
    #
    class Configuration < Common::Client::Configuration::REST
      def connection
        Faraday.new(base_path) do |conn|
          conn.use(:breakers, service_name:)
          conn.request :instrumentation, name: service_name
          conn.options.timeout = timeout
          conn.adapter Faraday.default_adapter
        end
      end

      def service_name
        'TimeOfNeed/MuleSoft'
      end

      # @return [Integer] Timeout in seconds, default 600
      def timeout
        settings.key?(:timeout) ? settings.timeout : 600
      end

      # @return [Config::Options]
      def settings
        Settings.time_of_need.mulesoft
      end

      private

      # @return [String] Base URL for the MuleSoft API
      def base_path
        settings.host
      end
    end
  end
end
