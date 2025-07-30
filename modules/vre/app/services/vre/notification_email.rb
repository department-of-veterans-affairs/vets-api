# frozen_string_literal: true

require 'veteran_facing_services/notification_email/saved_claim'

module VRE
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'veteran_readiness_and_employment')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      SavedClaim::VeteranReadinessEmploymentClaim
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#personalization
    def personalization
      default = super
      data = case @email_type
             when :action_needed
               {
                 'first_name' => parsed_form.dig('veteranInformation', 'fullName', 'first'),
                 'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                 'confirmation_number' => confirmation_number
               }
             else
               {
                 'first_name' => user&.first_name&.upcase.presence,
                 'date' => Time.zone.today.strftime('%B %d, %Y')
               }
             end
      default.merge(data)
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      VRE::NotificationCallback.to_s
    end

    # Add 'claim_id' to the metadata for consistency in DataDog and VRE::VREMonitor
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_metadata
    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
