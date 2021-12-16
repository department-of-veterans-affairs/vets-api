# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class SupplementalClaimCleanUpPii
    include Sidekiq::Worker

    def perform
      return unless enabled?

      AppealsApi::RemovePii.new(form_type: SupplementalClaim).run!
    end

    private

    def enabled?
      Settings.modules_appeals_api.supplemental_claim_pii_expunge_enabled
    end
  end
end
