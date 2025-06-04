# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module DhpConnectedDevices
  module Fitbit
    class Configuration < Common::Client::Configuration::REST
      def base_path
        'https://api.fitbit.com/oauth2/token'
      end

      def revoke_token_base_path
        'https://api.fitbit.com/oauth2/revoke'
      end

      def service_name
        'DHPConnectedDevices'
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
          conn.use(:breakers, service_name:)
          # conn.use :instrumentation, name: 'dhp.fitbit.request.faraday'

          # Uncomment this if you want curlggg command equivalent or response output to log
          # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
          # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

          # conn.response :raise_custom_error, error_prefix: service_name

          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
