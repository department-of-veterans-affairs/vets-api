# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'

module BenefitsReferenceData
  ##
  # HTTP client configuration for the {BenefitsReferenceData::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.

  module Staging
    class Configuration < Common::Client::Configuration::REST
      self.read_timeout = Settings.lighthouse.benefits_reference_data.timeout || 20

      ##
      # @return [String] Base path for benefits_reference_data URLs.
      #
      def base_path
        settings = Settings.lighthouse.benefits_reference_data
        url = settings.staging_url
        path = settings.path
        version = settings.version
        safe_slash_merge(url, path, version)
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'BenefitsReferenceDataStaging'
      end

      ##
      # @return [Hash] The basic headers required for any benefits_reference_data API call.
      #
      def self.base_request_headers
        key = Settings.lighthouse.staging_api_key
        message = "No api_key set for LH benefits_reference_data_staging. Please set 'lighthouse.staging_api_key'"
        raise message if key.nil?

        super.merge('apiKey' => key)
      end

      ##
      # Creates the a connection with parsing json and adding breakers functionality.
      #
      # @return [Faraday::Connection] a Faraday connection instance.
      #
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.use Faraday::Response::RaiseError

          faraday.request :multipart
          faraday.request :json
          faraday.response :json
          faraday.adapter Faraday.default_adapter
        end
      end

      private

      def safe_slash_merge(*url_segments)
        url_segments.map { |segment| segment.sub(%r{^/}, '').chomp('/') }.join('/')
      end
    end
  end
end
