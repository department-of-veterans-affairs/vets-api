# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'common/exceptions/forbidden'
require 'common/exceptions/schema_validation_errors'
require 'lighthouse/benefits_reference_data/configuration'
require 'lighthouse/benefits_reference_data/service_exception'

module BenefitsReferenceData
  ##
  # Proxy Service for the Lighthouse Benefits Reference Data API.
  #
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration BenefitsReferenceData::Configuration

    # ap @configuration.base_request_headers; exit

    STATSD_KEY_PREFIX = 'api.benefits_reference_data'

    ##
    # Hit a Benefits Reference Data End-point
    #
    # @path end-point [string|symbol] a string or symbol of the end-point you wish to hit.
    # @params params hash [Hash] a hash of key-value pairs of parameters
    #
    # @return [Faraday::Response]
    #
    def get_data(path:, params: {}, options: {})
      headers = config.base_request_headers

      # override api key if sent in options
      headers['apiKey'] = options[:api_key] if options[:api_key]
      settings = options[:settings] if options[:settings]
      begin
        response = perform :get, path, params, headers, {settings:}
      rescue => e
        raise BenefitsReferenceData::ServiceException.new(e), 'Lighthouse Error'
      end
      response
    end
  end
end
