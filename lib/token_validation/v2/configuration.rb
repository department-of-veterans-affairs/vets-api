# frozen_string_literal: true

require 'common/client/configuration/rest'

module TokenValidation
  module V2
    class Configuration < Common::Client::Configuration::REST
      def base_path
        "#{Settings.token_validation.url}/"
      end

      def service_name
        'TokenValidation'
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
          conn.use(:breakers, service_name:)
          conn.request :json
          conn.response :snakecase
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
