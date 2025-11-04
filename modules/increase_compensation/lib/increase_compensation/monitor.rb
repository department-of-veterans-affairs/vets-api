# frozen_string_literal: true

require 'increase_compensation/notification_email'
require 'logging/base_monitor'

module IncreaseCompensation
  ##
  # Monitor class for tracking claim submission events
  #
  # This class provides methods for tracking various events during the increase compensation
  # submission process, including successes, failures, and retries.
  #
  # @example Tracking a submission success
  #   monitor = IncreaseCompensation::Monitor.new
  #   monitor.track_submission_success(claim, service, user_uuid)
  #
  class Monitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.increase_compensation'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'worker.lighthouse.increase_compensation_intake_job'

    attr_reader :tags

    def initialize
      super('increase-compensation')

      @tags = ["form_id:#{form_id}"]
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'increase-compensation'
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
      IncreaseCompensation::FORM_ID
    end
  end
end
