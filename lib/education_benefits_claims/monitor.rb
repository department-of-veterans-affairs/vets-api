# frozen_string_literal: true

require 'logging/monitor'
require 'logging/base_monitor'

module EducationBenefitsClaims
  ##
  # Monitor class for tracking claim submission events
  #
  class Monitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.education_benefits'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'app.education_benefits.submit_benefits_intake_claim'

    attr_reader :saved_claim

    def initialize(saved_claim)
      @saved_claim = saved_claim
      super('education-benefits')
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'education-benefits'
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
    # Form ID
    # @return [String]
    def form_id
      saved_claim&.form_id || 'unknown'
    end
  end
end
