# frozen_string_literal: true

module VBMS
  module Efolder
    class Configuration < Common::Client::Configuration::Base

      def service_name
        'vbms_efolder'
      end

      def base_path
        Settings.vbms.url
      end

      # TODO: we are using connect_vbms gem for interaction with the vbms SOAP service, but we should
      # define something here to add breakers functionality. Does vbms have a health check endpoint?
      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use :breakers
          faraday.request :json

          faraday.response :raise_error, error_prefix: service_name
          faraday.response :betamocks if mock_enabled?
          faraday.response :json
          faraday.adapter Faraday.default_adapter
        end
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        [true, 'true'].include?(Settings.vbms.efolder.mock)
      end
    end
  end

end