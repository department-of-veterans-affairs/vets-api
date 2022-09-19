# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class SupplementalClaimCleanUpPii
    include Sidekiq::Worker
    # Only retry for ~8 hours since the job is run daily
    sidekiq_options retry: 11, unique_for: 8.hours

    def perform
      return unless enabled?

      AppealsApi::RemovePii.new(form_type: SupplementalClaim).run!
    end

    private

    def enabled?
      Flipper.enabled?(:decision_review_sc_pii_expunge_enabled)
    end
  end
end
