# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module Exceptions
    ##
    # ConfigurationError represents a configuration issue in the VAOS service
    # that prevents it from operating properly. This is used to provide a clean
    # API response when there are internal configuration issues.
    #
    class ConfigurationError < Common::Exceptions::ServiceError
      attr_reader :error

      ##
      # Initialize a new ConfigurationError
      #
      # @param error [StandardError] The original error that occurred
      # @param service_name [String] The name of the service that encountered the error
      #
      def initialize(error, service_name = 'VAOS')
        @error = error

        super(
          detail: "The #{service_name} service is unavailable due to a configuration issue",
          source: service_name
        )
      end

      ##
      # Returns the HTTP status code for this error
      #
      # @return [Integer] The HTTP status code (503 Service Unavailable)
      #
      def status
        503 # Service Unavailable
      end

      ##
      # Returns the error code
      #
      # @return [String] The error code
      #
      def code
        'VAOS_CONFIG_ERROR'
      end

      ##
      # Override i18n_data to provide custom error information
      #
      # @return [Hash] The error data
      #
      def i18n_data
        {
          title: 'Service Configuration Error',
          detail: @detail,
          code:,
          status: status.to_s
        }
      end
    end
  end
end
