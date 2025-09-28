# frozen_string_literal: true

require 'survivors_benefits/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'

module SurvivorsBenefits
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'survivors_benefits')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      SurvivorsBenefits::SavedClaim
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
        'date_received' => claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      }

      default.merge(template)
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      SurvivorsBenefits::NotificationCallback.to_s
    end
  end
end
