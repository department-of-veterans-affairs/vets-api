# frozen_string_literal: true

require 'dependents_verification/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'

module DependentsVerification
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'dependents_verification')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      DependentsVerification::SavedClaim
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#personalization
    def personalization
      default = super

      # confirmation, error
      dependents_verification = {
        'first_name' => claim.veteran_first_name&.titleize,
        'date_received' => claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      }

      default.merge(dependents_verification)
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      DependentsVerification::NotificationCallback.to_s
    end

    # Add 'claim_id' to the metadata for consistency in DataDog and DependentsVerification::Monitor
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_metadata
    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
