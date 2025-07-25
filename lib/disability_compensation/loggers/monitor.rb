# frozen_string_literal: true

require 'logging/base_monitor'

module DisabilityCompensation
  module Loggers
    ##
    # Monitor class for tracking Disability Compensation claim submission events
    #
    # This class will provide methods for tracking various events during the Disability Compensation
    # submission process, including successes, failures, and retries.
    #

    class Monitor < ::Logging::BaseMonitor
      SERVICE_NAME = 'disability-compensation'
      FORM_ID = '21-526EZ'

      # Metrics prefixes for SavedClaim and Form526Submission events, respectively
      CLAIM_STATS_KEY = 'api.disability_compensation.claim'
      SUBMISSION_STATS_KEY = 'api.disability_compensation.submission'

      def initialize
        super(SERVICE_NAME)
      end

      private

      ##
      # Module application name used for logging
      # @return [String]
      def service_name
        SERVICE_NAME
      end

      ##
      # Stats key for DD
      # @return [String]
      def claim_stats_key
        CLAIM_STATS_KEY
      end

      ##
      # Stats key for Sidekiq DD logging
      # @return [String]
      def submission_stats_key
        SUBMISSION_STATS_KEY
      end

      ##
      # Class name for log messages
      # @return [String]
      def name
        self.class.name
      end

      ##
      # Form ID for the application
      # @return [String]
      def form_id
        FORM_ID
      end
    end
  end
end
