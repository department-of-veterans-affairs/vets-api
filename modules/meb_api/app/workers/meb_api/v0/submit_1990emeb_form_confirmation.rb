# frozen_string_literal: true

require 'sidekiq'

module MebApi
  module V0
    class Submit1990emebFormConfirmation
      include Sidekiq::Worker
      include SentryLogging
      sidekiq_options retry: 14

      def perform(claim_status, email, first_name)
        @claim_status = claim_status

        VANotify::EmailJob.perform_async(
          email,
          confirmation_email_template_id,
          {
            'first_name' => first_name,
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
          }
        )
      end

      private

      def confirmation_email_template_id
        case @claim_status
        when 'ELIGIBLE'
          Settings.vanotify.services.va_gov.template_id.form1990emeb_approved_confirmation_email
        when 'DENIED'
          Settings.vanotify.services.va_gov.template_id.form1990emeb_denied_confirmation_email
        else
          Settings.vanotify.services.va_gov.template_id.form1990emeb_offramp_confirmation_email
        end
      end
    end
  end
end
