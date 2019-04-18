# frozen_string_literal: true

module EVSS
  module Dependents
    class Configuration < EVSS::Configuration
      def base_path
        "#{Settings.evss.url}/wss-686-services-web-2.6/rest/"
      end

      def service_name
        'EVSS/Dependents'
      end

      def connection
        @conn ||= Faraday.new(base_path, request: request_options, ssl: ssl_options) do |faraday|
          set_evss_middlewares(faraday, snakecase: false)
        end
      end
    end
  end
end
