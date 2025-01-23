# frozen_string_literal: true

require 'veteran_facing_services/notification_email/saved_claim'

module Pensions
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'pensions')
    end

    private

    def claim_class
      Pensions::SavedClaim
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#personalization
    def personalization
      default = super

      # confirmation, error
      pensions = {
        'first_name' => claim.first_name&.titleize,
        'date_received' => claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      }

      default.merge(pensions)
    end
  end
end
