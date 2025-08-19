# frozen_string_literal: true

require 'accredited_representative_portal/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'

module AccreditedRepresentativePortal
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'accredited_representative_portal')
    end

    private

    def claim_class
      ::SavedClaim
    end

    def form_id
      claim.class::PROPER_FORM_ID
    end

    def saved_claim_claimant_representative
      @saved_claim_claimant_representative ||=
        SavedClaimClaimantRepresentative.find_by(saved_claim_id: claim.id)
    end

    def representative
      @representative ||= begin
        rep_id = saved_claim_claimant_representative&.accredited_individual_registration_number
        Veteran::Service::Representative.find_by(representative_id: rep_id) if rep_id
      end
    end

    def personalization
      default = super

      {
        'form_id' => form_id,
        'confirmation_number' => claim&.latest_submission_attempt&.benefits_intake_uuid,
        'first_name' => representative&.first_name || 'Representative',
        'submission_date' => claim&.created_at&.strftime('%B %-d, %Y')
      }.reverse_merge(default)
    end

    def email
      representative&.email
    end

    def callback_klass
      AccreditedRepresentativePortal::NotificationCallback.to_s
    end

    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
