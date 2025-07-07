# frozen_string_literal: true

module VRE
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'vre-application')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      SavedClaim::VeteranReadinessEmploymentClaim
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#personalization
    def personalization
      default = super
      data = {}
      case @email_type
      when :confirmation_lighthouse
        data = {
          'first_name' => user&.first_name&.upcase.presence,
          'date' => Time.zone.today.strftime('%B %d, %Y')
        }
      when :confirmation_vbms
        data = {
          'first_name' => user&.first_name&.upcase.presence,
          'date' => Time.zone.today.strftime('%B %d, %Y')
        }
      when :action_needed
        data = {
          'first_name' => parsed_form.dig('veteranInformation', 'fullName', 'first'),
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => confirmation_number
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
