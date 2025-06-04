# frozen_string_literal: true

require 'burials/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'

module Burials
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'burials')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      Burials::SavedClaim
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#personalization
    def personalization
      default = super

      facility_name, street_address, city_state_zip = claim.regional_office
      veteran_name = "#{claim.veteran_first_name} #{claim.veteran_last_name&.first}"
      benefits_claimed = " - #{claim.benefits_claimed.join(" \n - ")}"

      burials = {
        # confirmation
        'form_name' => 'Burial Benefit Claim (Form 21P-530)',
        'deceased_veteran_first_name_last_initial' => veteran_name,
        'benefits_claimed' => benefits_claimed,
        'facility_name' => facility_name,
        'street_address' => street_address,
        'city_state_zip' => city_state_zip,
        # confirmation, error
        'first_name' => claim.claimant_first_name&.upcase,
        # received
        'date_received' => claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      }

      default.merge(burials)
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      Burials::NotificationCallback.to_s
    end

    # Add 'claim_id' to the metadata for consistency in DataDog and Burials::Monitor
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_metadata
    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
