# frozen_string_literal: true

require 'logging/base_monitor'

module VRE
  class VREMonitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'vre-application'
    # statsd key for initial sidekiq
    SUBMISSION_STATS_KEY = 'worker.vre.vre_submit_1900_job'

    attr_reader :tags

    def initialize
      super('veteran_readiness_and_employment')
      @tags = ["form_id:#{form_id}"]
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'vre-application'
    end

    #
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
    # @return [String]
    def form_id
      VRE::FORM_ID
    end
  end
end
