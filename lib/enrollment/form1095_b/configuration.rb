# frozen_string_literal: true

module Enrollment
  module Form1095B
    ##
    # HTTP client configuration for the {Form1095BEnrollment::Service},
    # sets the base path, the base request headers, and a service name for breakers and metrics.
    #
    class Configuration < Common::Client::Configuration::REST
      # Configuration parameters
      self.read_timeout = Settings.form1095b_enrollment&.timeout || 30
      self.open_timeout = Settings.form1095b_enrollment&.open_timeout || 15

      ##
      # @return [String] Base path for Form 1095-B enrollment API URLs.
      #
      def base_path
        Settings.form1095b_enrollment.url
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'Form1095BEnrollment'
      end

      ##
      # @return [Hash] The base request headers for Form 1095-B enrollment API.
      #
      def base_request_headers
        headers = super
        headers.merge!(
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        )

        # Add API key if configured in settings
        if Settings.form1095b_enrollment&.api_key.present?
          headers['apiKey'] = Settings.form1095b_enrollment.api_key
        end

        headers
      end

      ##
      # @return [Boolean] Whether the mock feature is enabled.
      #
      def mock_enabled?
        # Enable mock when in test mode or when explicitly configured
        [true, 'true'].include?(Settings.form1095b_enrollment&.mock)
      end

      ##
      # @return [Faraday::Connection] A new Faraday connection based on the configuration parameters
      #
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.request :json
          faraday.response :raise_error
          faraday.response :betamocks if mock_enabled?
          faraday.response :json, content_type: /\bjson$/i
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
