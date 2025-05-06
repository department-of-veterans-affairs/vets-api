# frozen_string_literal: true

require 'veteran_facing_services/notification_email/saved_claim'

module Dependents
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id, user = nil)
      @va_profile_email = user&.va_profile_email
      @user_first_name = user&.first_name
      super(saved_claim_id, service_name: 'dependents')
    end

    private

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      SavedClaim::DependencyClaim
    end

    # retrieve the email from the _claim_ or _user_
    def email
      @va_profile_email || claim.parsed_form.dig('dependents_application', 'veteran_contact_information',
                                                 'email_address')
    end

    # assemble details for personalization in the emails
    def personalization
      default = super

      submission_date = claim.submitted_at || Time.zone.today
      first_name = @user_first_name || claim.parsed_form.dig('veteran_information', 'full_name', 'first')
      dependents = {
        'first_name' => first_name&.upcase&.presence,
        'date_submitted' => submission_date.strftime('%B %d, %Y'),
        'confirmation_number' => claim.confirmation_number
      }

      default.merge(dependents)
    end
  end
end
