# frozen_string_literal: true

module ClaimsApi
  class VANotifyDeclinedJob < ClaimsApi::ServiceBase
    LOG_TAG = 'va_notify_declined_job'

    def perform(poa_id)
      return if Rails.env.test?

      poa = ClaimsApi::PowerOfAttorney.find(poa_id)

      unless poa
        raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
          detail: "Could not find Power of Attorney with id: #{poa_id}"
        )
      end

      begin
        res = send_declined_notification(poa)

        ClaimsApi::VANotifyFollowUpJob.perform_async(res.id) if res.present?
      rescue => e
        msg = "VA Notify email notification failed to send for #{poa_id} with error #{e}"
        slack_client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                               channel: '#api-benefits-claims-alerts',
                                               username: 'Failed ClaimsApi::VANotifyDeclinedJob')

        slack_client.notify(msg)
        ClaimsApi::Logger.log(LOG_TAG, detail: msg)

        raise e
      end
    end

    private

    def send_declined_notification(poa)
      return send_organization_notification(poa) if poa.form_data['serviceOrganization'].present?

      send_representative_notification(poa)
    end

    def send_organization_notification(poa)
      content = {
        recipient_identifier: recipient_identifier(poa),
        personalisation: {
          first_name: poa.auth_headers['va_eauth_firstName'] || '',
          form_type: "Appointment of Veterans Service Organization as Claimant's Representative (VA Form 21-22)"
        },
        template_id: Settings.claims_api.vanotify.declined_service_organization_template_id
      }

      vanotify_service.send_email(content)
    end

    def send_representative_notification(poa)
      representative_type = poa.form_data.dig('representative', 'type')

      content = {
        recipient_identifier: recipient_identifier(poa),
        personalisation: {
          first_name: poa.auth_headers['va_eauth_firstName'] || '',
          representative_type: representative_type || '',
          representative_type_abbreviated: representative_type_abbreviated(representative_type),
          form_type: "Appointment of Individual as Claimant's Representative (VA Form 21-22a)"
        },
        template_id: Settings.claims_api.vanotify.declined_representative_template_id
      }

      vanotify_service.send_email(content)
    end

    def representative_type_abbreviated(representative_type)
      representative_type == 'Veteran Service Organization (VSO)' ? 'VSO' : representative_type
    end

    def recipient_identifier(poa)
      poa.auth_headers[ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY]
    end

    def vanotify_service
      VaNotify::Service.new(Settings.claims_api.vanotify.services.lighthouse.api_key)
    end
  end
end
