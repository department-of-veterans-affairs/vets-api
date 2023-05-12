# frozen_string_literal: true

require 'common/client/configuration/rest'

module FormsApiSubmission
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 20 # using the same timeout as lighthouse

    ##
    # @return [String] Base path
    #
    def base_path
      Settings.forms_api_benefits_intake.url
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'FormsApiSubmission'
    end

    ##
    # @return [Hash] The basic headers required for any Lighthouse API call
    #
    def self.base_request_headers
      super.merge('apikey' => Settings.forms_api_benefits_intake.api_key)
    end

    ##
    # Creates a connection with json parsing and breaker functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        faraday.request :multipart
        faraday.request :json

        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
