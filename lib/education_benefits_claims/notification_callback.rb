# frozen_string_literal: true

require 'education_benefits_claims/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module EducationBenefitsClaims
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    def monitor
      claim = SavedClaim::EducationBenefits.find_by(id: saved_claim_id)
      @monitor ||= EducationBenefitsClaims::Monitor.new(claim)
    end
  end
end
