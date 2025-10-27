# frozen_string_literal: true

require 'employment_questionairres/notification_email'
require 'logging/base_monitor'

module EmploymentQuestionairres
  ##
  # Monitor class for tracking claim submission events
  #
  # This class provides methods for tracking various events during the burial claim
  # submission process, including successes, failures, and retries.
  #
  # @example Tracking a submission success
  #   monitor = EmploymentQuestionairres::Monitor.new
  #   monitor.track_submission_success(claim, service, user_uuid)
  #
  class Monitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.employment_questionairres'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'worker.lighthouse.employment_questionairres_intake_job'

    attr_reader :tags

    def initialize
      super('employment-questionairres')

      @tags = ["form_id:#{form_id}"]
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'employment-questionairres'
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
      EmploymentQuestionairres::FORM_ID
    end
  end
end
