module AccreditedRepresentativePortal
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'accredited_representative_portal')
    end

    private

    def claim_class
      AccreditedRepresentativePortal::SavedClaim
    end

    def personalization
      default = super

      {
        'confirmation_number' => claim.confirmation_number,
        'representative_name' => claim.representative_name,
        'first_name' => claim.claimant_first_name&.upcase
      }.merge(default)
    end

    def callback_klass
      AccreditedRepresentativePortal::NotificationCallback.to_s
    end

    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
