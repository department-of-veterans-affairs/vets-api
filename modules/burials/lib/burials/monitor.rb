# frozen_string_literal: true

require 'burials/notification_email'
require 'zero_silent_failures/monitor'
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

    attr_reader :tags

    def initialize
      super('burial-application')

      @tags = ["form_id:#{form_id}"]
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

    ##
    # Class name for notification email
    # @return [Class]
    def send_email(claim_id, email_type)
      Burials::NotificationEmail.new(claim_id).deliver(email_type)
    end
  end
end
