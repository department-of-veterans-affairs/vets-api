# frozen_string_literal: true

require 'logging/include/benefits_intake'
require 'logging/monitor'

module BenefitsIntake
  # generic monitor for Lighthouse Benefits Intake
  class Monitor < ::Logging::Monitor
    include ::Logging::Include::BenefitsIntake

    ALLOWLIST = %w[
      benefits_intake_uuid
      claim_id
      confirmation_number
      error
      form_id
      user_account_uuid
    ].freeze

    # create a benefits intake monitor
    #
    # @param allowlist [Array<String>] list of allowed params
    def initialize
      super('lighthouse-benefits-intake', allowlist: ALLOWLIST)
    end

    private

    # message prefix to prepend
    # @return [String]
    def message_prefix
      self.class.to_s
    end

    # Stats key for Sidekiq DD logging
    # @return [String]
    def submission_stats_key
      'worker.lighthouse.benefits_intake'
    end
  end
end
