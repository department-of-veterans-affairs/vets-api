# frozen_string_literal: true

module CentralMail
  class SubmitCareerCounselingJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(claim_id)
      @claim = SavedClaim.find(claim_id)
      @claim.send_to_central_mail!
      send_confirmation_email
    end

    def send_confirmation_email
      return unless Flipper.enabled?(:career_counseling_confirmation_email)

      VANotify::EmailJob.perform_async(
        @claim.parsed_form.dig('claimantInformation', 'emailAddress'),
        Settings.vanotify.services.va_gov.template_id.career_counseling_confirmation_email,
        {
          'first_name' => @claim.parsed_form.dig('claimantInformation', 'fullName', 'first')&.upcase.presence,
          'date' => Time.zone.today.strftime('%B %d, %Y')
        }
      )
    end
  end
end
