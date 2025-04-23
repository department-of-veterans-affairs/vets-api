# frozen_string_literal: true

require 'income_and_assets/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'

module IncomeAndAssets
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'income_and_assets')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      IncomeAndAssets::SavedClaim
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#personalization
    # {
    #   'date_submitted' => claim.submitted_at,
    #   'confirmation_number' => claim.confirmation_number
    # }
    def personalization
      default = super

      template = {
        # confirmation, error
        'first_name' => claim.claimant_first_name&.titleize,
        # received
        'date_received' => claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      }

      default.merge(template)
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      IncomeAndAssets::NotificationCallback.to_s
    end
  end
end
