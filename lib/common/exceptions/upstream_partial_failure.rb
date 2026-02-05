# frozen_string_literal: true

require 'common/exceptions/service_error'

module Common
  module Exceptions
    # Exception raised when an upstream service returns partial data due to failures
    # in one or more data sources (e.g., Oracle Health rate limiting while VistA succeeds)
    class UpstreamPartialFailure < ServiceError
      attr_reader :failed_sources, :failure_details

      # @param options [Hash] Configuration options
      # @option options [Array<String>] :failed_sources List of sources that failed (e.g., ['oracle-health'])
      # @option options [Array<Hash>] :failure_details Detailed failure information with source, code, and diagnostics
      # @option options [String] :detail Custom error message
      def initialize(options = {})
        @failed_sources = options[:failed_sources] || []
        @failure_details = options[:failure_details] || []

        super(
          detail: options[:detail] || build_default_detail,
          source: options[:source]
        )
      end

      private

      def build_default_detail
        if @failed_sources.any?
          "Partial data failure: some health records could not be retrieved from #{@failed_sources.join(', ')}"
        else
          'Partial data failure: some health records could not be retrieved'
        end
      end
    end
  end
end
