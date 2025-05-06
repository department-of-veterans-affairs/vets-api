# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module Lighthouse
  module VeteransHealth
    class Configuration < Common::Client::Configuration::REST
      def base_path
        Settings.lighthouse.veterans_health.url
      end

      def service_name
        'Lighthouse_VeteransHealth'
      end

      def rsa_key
        @key ||= OpenSSL::PKey::RSA.new(File.read(Settings.lighthouse.veterans_health.fast_tracker.api_key))
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.use Faraday::Response::RaiseError

          # This is necessary to pass multiple date query params to Lighthouse
          # e.g. "date=foo&date=bar"
          faraday.options.params_encoder = Faraday::FlatParamsEncoder

          # Uncomment this if you want curl command equivalent or response output to log
          # faraday.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
          # faraday.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

          faraday.response :json

          faraday.response :betamocks if Settings.lighthouse.veterans_health.use_mocks
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
