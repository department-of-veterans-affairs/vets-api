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
        'date_received' => claim.form_submissions&.last&.form_submission_attempts&.last&.lighthouse_updated_at
      }

      default.merge(pensions)
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      Pensions::NotificationCallback.to_s
    end

    # assemble the metadata to be sent with the notification
    # Change 'saved_claim_id' to 'claim_id' in the metadata
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_metadata
    def callback_metadata
      {
        form_id: claim.form_id,
        claim_id: claim.id,
        service_name: vanotify_service,
        email_type:,
        email_template_id:
      }
    end
  end
end
