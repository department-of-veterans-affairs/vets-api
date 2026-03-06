# frozen_string_literal: true

require 'logging/base_monitor'

module Burials
  ##
  # Monitor class for tracking claim submission events
  #
  # This class provides methods for tracking various events during the burial claim
  # submission process, including successes, failures, and retries.
  #
  # @example Tracking a submission success
  #   monitor = Burials::Monitor.new
  #   monitor.track_submission_success(claim, service, user_uuid)
  #
  class Monitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.burial_claim'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'app.burial.submit_benefits_intake_claim'

    def initialize
      super('burial-application', allowlist: %w[relationship_to_veteran])
    end

    ##
    # Override of {Logging::Include::Controller#track_create_success} to include
    # the claimant's relationship to the veteran in the logged context.
    #
    # Extracts `relationshipToVeteran` from the claim's parsed form data and
    # passes it as `relationship_to_veteran` for DataDog tracking. This value
    # (e.g., "spouse", "child") is not PII and is safe to log.
    #
    # @param in_progress_form [InProgressForm, nil] the in-progress form, if any
    # @param claim [SavedClaim] the burial claim being submitted
    # @param current_user [User, nil] the authenticated user, if present
    #
    def track_create_success(in_progress_form, claim, current_user)
      parsed_form = claim&.parsed_form || {}
      relationship_to_veteran = parsed_form['relationshipToVeteran']

      submit_event(
        :info,
        "#{message_prefix} submission to Sidekiq success",
        "#{claim_stats_key}.success",
        claim:,
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        relationship_to_veteran:
      )
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'burial-application'
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
    # Form ID for the burial application
    # @return [String]
    def form_id
      Burials::FORM_ID
    end
  end
end
