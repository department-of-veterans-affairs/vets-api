# frozen_string_literal: true

require 'pensions/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'

module Pensions
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'pensions')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      Pensions::SavedClaim
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#personalization
    def personalization
      default = super

      # confirmation, error
      pensions = {
        'first_name' => claim.first_name&.titleize,
        'date_received' => date_received
      }

      default.merge(pensions)
    end

    # Provides the date received with fallback to claim submission date
    # @return [Time] the date the form was received or submitted
    def date_received
      lighthouse_date = claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      lighthouse_date || claim.submitted_at || claim.created_at
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      Pensions::NotificationCallback.to_s
    end

    # Add 'claim_id' to the metadata for consistency in DataDog and Pensions::Monitor
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_metadata
    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
