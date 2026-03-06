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

    # ---- Sidekiq submission tracking ----

    ##
    # Track when a MuleSoft submission attempt begins
    #
    # @param claim [TimeOfNeed::SavedClaim]
    def track_submission_attempt(claim)
      submit_event(
        :info,
        "#{message_prefix} submission attempt",
        "#{SUBMISSION_STATS_KEY}.attempt",
        claim:,
        call_location: caller_locations.first
      )
    end

    ##
    # Track a successful MuleSoft submission
    #
    # @param claim [TimeOfNeed::SavedClaim]
    # @param response [Hash] MuleSoft response
    def track_submission_success(claim, response = nil)
      submit_event(
        :info,
        "#{message_prefix} submission success",
        "#{SUBMISSION_STATS_KEY}.success",
        claim:,
        call_location: caller_locations.first
      )
    end

    ##
    # Track a MuleSoft submission failure
    #
    # @param claim [TimeOfNeed::SavedClaim]
    # @param error [Exception]
    def track_submission_failure(claim, error = nil)
      submit_event(
        :error,
        "#{message_prefix} submission failure: #{error&.message}",
        "#{SUBMISSION_STATS_KEY}.failure",
        claim:,
        error:,
        call_location: caller_locations.first
      )
    end

    ##
    # Track when Sidekiq retries are exhausted for a submission
    #
    # @param msg [Hash] Sidekiq message
    # @param claim [TimeOfNeed::SavedClaim, nil]
    def track_submission_exhaustion(msg, claim = nil)
      submit_event(
        :error,
        "#{message_prefix} submission retries exhausted",
        "#{SUBMISSION_STATS_KEY}.exhausted",
        claim:,
        error: msg['error_message'],
        call_location: caller_locations.first
      )
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
