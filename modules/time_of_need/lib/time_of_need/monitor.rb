# frozen_string_literal: true

require 'logging/base_monitor'

module TimeOfNeed
  ##
  # Monitor class for tracking Time of Need claim submission events
  #
  # Provides StatsD metrics and structured logging for the submission pipeline.
  # Follows the zero silent failures pattern.
  #
  # @example
  #   monitor = TimeOfNeed::Monitor.new
  #   monitor.track_create_attempt(claim, current_user)
  #
  class Monitor < ::Logging::BaseMonitor
    # StatsD key for API (controller) events
    CLAIM_STATS_KEY = 'api.time_of_need_claim'
    # StatsD key for Sidekiq (submission) events
    SUBMISSION_STATS_KEY = 'app.time_of_need.submit_to_mulesoft'

    def initialize
      super('time-of-need')
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'time-of-need'
    end

    ##
    # StatsD key for controller events
    # @return [String]
    def claim_stats_key
      CLAIM_STATS_KEY
    end

    ##
    # StatsD key for Sidekiq submission events
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
    # Form ID for the Time of Need application
    # @return [String]
    def form_id
      TimeOfNeed::FORM_ID
    end
  end
end
