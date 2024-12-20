# frozen_string_literal: true

require 'va_notify/notification_email/saved_claim'

# Form 21P-530EZ
module Burials
  # @see VANotify::NotificationEmail::SavedClaim
  class NotificationEmail < ::VANotify::NotificationEmail::SavedClaim
    # @see VANotify::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'burials')
    end

    private

    def claim_class
      SavedClaim::Burial
    end

    # @see VANotify::NotificationEmail::SavedClaim#personalization
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
        'first_name' => claim.claimaint_first_name&.upcase
      }

      default.merge(burials)
    end
  end
end
