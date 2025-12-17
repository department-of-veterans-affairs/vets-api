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

    # Capture the first name of the claimant or veteran
    # @return [String] the first name of the claimant or veteran
    # If neither is available, defaults to 'Veteran'
    def first_name
      first = claim.claimant_first_name || claim.veteran_first_name

      first&.titleize || 'Veteran'
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
        'first_name' => first_name,
        # received
        'date_received' => date_received
      }

      default.merge(template)
    end

    # Provides the date received with fallback to claim submission date
    # @return [Time] the date the form was received or submitted
    def date_received
      lighthouse_date = claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      lighthouse_date || claim.submitted_at || claim.created_at
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      IncomeAndAssets::NotificationCallback.to_s
    end
  end
end
