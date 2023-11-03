# frozen_string_literal: true

module CentralMail
  class SubmitCareerCounselingJob
    include Sidekiq::Job
    include SentryLogging

    sidekiq_options retry: false

    def perform(claim_id, user_uuid = nil)
      begin
        @claim = SavedClaim.find(claim_id)
        @claim.send_to_central_mail!
        send_confirmation_email(user_uuid)
      rescue => e
        log_message_to_sentry('Error submitting form 25-8832', :error, { uuid: user_uuid })
        log_exception_to_sentry(e, { uuid: user_uuid })
        raise e
      end
      log_message_to_sentry('Successfully submitted form 25-8832', :info, { uuid: user_uuid })
    end

    def send_confirmation_email(user_uuid)
      email = if user_uuid.present? && (found_email = User.find(user_uuid)&.va_profile_email)
                found_email
              else
                @claim.parsed_form.dig('claimantInformation', 'emailAddress')
              end

      if email.blank?
        log_message_to_sentry('No email to send confirmation regarding submitted form 25-8832', :info,
                              { uuid: user_uuid })
        return
      end

      VANotify::EmailJob.perform_async(
        email,
        Settings.vanotify.services.va_gov.template_id.career_counseling_confirmation_email,
        {
          'first_name' => @claim.parsed_form.dig('claimantInformation', 'fullName', 'first')&.upcase.presence,
          'date' => Time.zone.today.strftime('%B %d, %Y')
        }
      )
    end
  end
end
