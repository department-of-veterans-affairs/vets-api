# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Configuration for the 526 form, used by the {EVSS::DisabilityCompensationForm::Service} to
    # set the base path, a default timeout, and a service name for breakers and metrics
    #
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.disability_compensation_form.timeout || 55

      # @return [String] The base path for the EVSS 526 endpoints
      #
      def base_path
        "#{Settings.evss.url}/#{Settings.evss.alternate_service_name}/rest/form526/v2"
      end

      # @return [String] The name of the service, used by breakers to set a metric name for the service
      #
      def service_name
        'EVSS/DisabilityCompensationForm'
      end

      # @return [Boolean] Whether or not Betamocks mock data is enabled
      #
      def mock_enabled?
        Settings.evss.mock_disabilities_form || false
      end

      def connection
        @conn ||= Faraday.new(base_path, request: request_options, ssl: ssl_options) do |faraday|
          faraday.use      :breakers
          faraday.use      EVSS::ErrorMiddleware
          faraday.use      Faraday::Response::RaiseError
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          # calls to EVSS returns non JSON responses for some scenarios that don't make it through VAAFI
          # content_type: /\bjson$/ ensures only json content types are attempted to be parsed.
          faraday.response :json, content_type: /\bjson$/
          faraday.use :immutable_headers
          faraday.use      ::EVSS::DisabilityCompensationForm::Form526TimeoutMiddleware
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
