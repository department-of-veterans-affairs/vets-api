# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'

module Form526BackupSubmission
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.caseflow.timeout || 20 # using the same timeout as lighthouse

    ##
    # @return [String] Base path
    #
    def base_path
      Settings.form526_backup.url
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'Form526BackupSubmission'
    end

    ##
    # @return [Hash] The basic headers required for any Lighthouse API call
    #
    def self.base_request_headers
      super.merge('apikey' => Settings.form526_backup.api_key)
    end

    ##
    # Creates a connection with json parsing and breaker functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

        faraday.request :multipart
        faraday.request :json

        faraday.response :betamocks if mock_enabled?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def mock_enabled?
      Settings.form526_backup.mock || false
    end

    def breakers_error_threshold
      80 # breakers will be tripped if error rate reaches 80% over a two minute period.
    end
  end
end
