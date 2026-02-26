# frozen_string_literal: true

require 'education_benefits_claims/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'

module EducationBenefitsClaims
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      ::SavedClaim::EducationBenefits
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#personalization
    def personalization
      default = super
      default.merge(claim.personalisation)
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      EducationBenefitsClaims::NotificationCallback.to_s
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_metadata
    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
