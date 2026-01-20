# frozen_string_literal: true

require 'increase_compensation/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'

module IncreaseCompensation
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'increase_compensation')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      IncreaseCompensation::SavedClaim
    end

    # Capture the first name of the claimant or veteran
    # @return [String] the first name of the claimant or veteran
    # If neither is available, defaults to 'Veteran'
    def first_name
      first = claim.claimant_first_name || claim.veteran_first_name

      first&.titleize || 'Veteran'
    end

    # Provides the date received with fallback to claim submission date
    # @return [Time] the date the form was received or submitted
    def date_received
      lighthouse_date = claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      lighthouse_date || claim.submitted_at || claim.created_at
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

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      IncreaseCompensation::NotificationCallback.to_s
    end

    # Add 'claim_id' to the metadata for consistency in DataDog and IncreaseCompensation::Monitor
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_metadata
    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
