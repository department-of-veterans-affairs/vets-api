# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module IvcChampva
  module LlmProcessorApi
    class Configuration < Common::Client::Configuration::REST
      # Override the default timeouts from lib/common/client/configuration/base.rb
      self.open_timeout = 45
      self.read_timeout = 45

      def settings
        Settings.ivc_champva_llm_processor_api
      end

      delegate :host, to: :settings
      delegate :api_key, to: :settings

      def base_path
        settings.host
      end

      def service_name
        'LlmProcessorApi::Client'
      end

      def connection
        headers = base_request_headers.except('Content-Type')
        Faraday.new(base_path, headers:, request: request_options) do |conn|
          conn.use(:breakers, service_name:)
          conn.request :multipart
          conn.response :json
          # conn.use :instrumentation, name: 'ivc_champva.llm_processor.request.faraday'

          # Uncomment this if you want curl command equivalent or response output to log
          # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
          # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

          # conn.response :raise_custom_error, error_prefix: service_name

          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
