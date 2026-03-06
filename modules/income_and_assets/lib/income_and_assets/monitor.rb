# frozen_string_literal: true

require 'income_and_assets/notification_email'
require 'logging/base_monitor'

module IncomeAndAssets
  ##
  # Monitor class for tracking claim submission events
  #
  # This class provides methods for tracking various events during the burial claim
  # submission process, including successes, failures, and retries.
  #
  # @example Tracking a submission success
  #   monitor = IncomeAndAssets::Monitor.new
  #   monitor.track_submission_success(claim, service, user_uuid)
  #
  class Monitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.income_and_assets'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'worker.lighthouse.income_and_assets_intake_job'

    def initialize
      super('income-and-assets', allowlist: %w[claimant_type])
    end

    ##
    # Override of {Logging::Include::Controller#track_create_success} to include
    # the claimant type in the logged context.
    #
    # Extracts `claimantType` from the claim's parsed form data and passes it
    # as `claimant_type` for DataDog tracking. This value (e.g., "SPOUSE",
    # "VETERAN") is not PII and is safe to log.
    #
    # @param in_progress_form [InProgressForm, nil] the in-progress form, if any
    # @param claim [SavedClaim] the income and assets claim being submitted
    # @param current_user [User, nil] the authenticated user, if present
    #
    def track_create_success(in_progress_form, claim, current_user)
      parsed_form = claim&.parsed_form || {}
      claimant_type = parsed_form['claimantType']

      submit_event(
        :info,
        "#{message_prefix} submission to Sidekiq success",
        "#{claim_stats_key}.success",
        claim:,
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        claimant_type:
      )
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'income-and-assets'
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
      IncomeAndAssets::FORM_ID
    end
  end
end
