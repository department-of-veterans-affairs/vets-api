# frozen_string_literal: true

require 'sidekiq'
require 'vets/shared_logging'

module MebApi
  module V0
    class Submit1990mebFormConfirmation
      include Sidekiq::Worker
      include Vets::SharedLogging
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
      rescue => e
        log_exception_to_rails(e)
      end

      private

      def confirmation_email_template_id
        case @claim_status
        when 'ELIGIBLE'
          Settings.vanotify.services.va_gov.template_id.form1990meb_approved_confirmation_email
        when 'DENIED'
          Settings.vanotify.services.va_gov.template_id.form1990meb_denied_confirmation_email
        else
          Settings.vanotify.services.va_gov.template_id.form1990meb_offramp_confirmation_email
        end
      end
    end
  end
end
