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

      @tags = ['form_id:21P-530EZ']
    end

    private

    def service_name
      'burial-application'
    end

    def claim_stats_key
      CLAIM_STATS_KEY
    end

    def submission_stats_key
      SUBMISSION_STATS_KEY
    end

    def name
      self.class.name
    end

    def form_id
      Burials::FORM_ID
    end

    def notification_email_class
      Burials::NotificationEmail
    end
  end
end
