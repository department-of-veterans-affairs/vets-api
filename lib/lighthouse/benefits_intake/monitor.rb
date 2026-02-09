# frozen_string_literal: true

require 'logging/include/benefits_intake'
require 'logging/base_monitor'

module BenefitsIntake
  # generic monitor for Lighthouse Benefits Intake
  class Monitor < ::Logging::BaseMonitor
    # create a benefits intake monitor
    def initialize
      super('lighthouse-benefits-intake')
      @tags = [] # no form_id so need to override the base value
    end

    private

    # @see ::Logging::BaseMonitor#message_prefix
    def message_prefix
      self.class.to_s
    end

    # @see ::Logging::BaseMonitor#submission_stats_key
    def submission_stats_key
      'worker.lighthouse.benefits_intake'
    end

    # @see ::Logging::BaseMonitor#message_prefix
    def form_id
      false
    end
  end
end
