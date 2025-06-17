# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module IvcChampva
  module PegaApi
    class Configuration < Common::Client::Configuration::REST
      def base_path
        Settings.ivc_champva.pega_api.base_path.to_s
      end

      def service_name
        'PEGA_API'
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
