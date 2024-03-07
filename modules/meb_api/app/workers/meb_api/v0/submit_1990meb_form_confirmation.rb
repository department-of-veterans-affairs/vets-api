# frozen_string_literal: true

require 'sidekiq'
require 'dgi/claimant/service'
require 'dgi/status/service'

module MebApi
  module V0
    class Submit1990mebFormConfirmation
      include Sidekiq::Worker
      include SentryLogging
      sidekiq_options retry: 14

      def perform(user_uuid, email, first_name)
        @current_user = User.find(user_uuid)

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
        claimant_service = MebApi::DGI::Claimant::Service.new(@current_user)
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']
        claim_status_service = MebApi::DGI::Status::Service.new(@current_user)
        claim_status_response = claim_status_service.get_claim_status({ latest: false }, claimant_id)
        claim_status = claim_status_response['claim_status']

        if claim_status.eql? 'ELIGIBLE'
          Settings.vanotify.services.va_gov.template_id.form1990meb_approved_confirmation_email
        elsif claim_status.eql? 'DENIED'
          Settings.vanotify.services.va_gov.template_id.form1990meb_denied_confirmation_email
        else
          Settings.vanotify.services.va_gov.template_id.form1990meb_offramp_confirmation_email
        end
      end
    end
  end
end
