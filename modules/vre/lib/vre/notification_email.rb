# frozen_string_literal: true

require 'veteran_facing_services/notification_email/saved_claim'
require 'vre/notification_callback'

module VRE
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'veteran_readiness_and_employment')
    end

    private

    def claim_class
      SavedClaim::VeteranReadinessEmploymentClaim
    end

    def personalization
      default = super
      data = case @email_type
             when :error
               {
                 'first_name' => claim.parsed_form.dig('veteranInformation', 'fullName', 'first'),
                 'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                 'confirmation_number' => claim.confirmation_number
               }
             else
               {
                 'first_name' => claim.parsed_form.dig('veteranInformation', 'fullName', 'first'),
                 'date' => Time.zone.today.strftime('%B %d, %Y')
               }
             end
      default.merge(data)
    end

    def callback_klass
      VRE::NotificationCallback.to_s
    end

    # Add 'claim_id' to the metadata for consistency in DataDog and VRE::VREMonitor
    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
