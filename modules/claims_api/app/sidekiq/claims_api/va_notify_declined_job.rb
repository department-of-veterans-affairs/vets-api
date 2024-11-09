# frozen_string_literal: true

module ClaimsApi
  class VANotifyDeclinedJob < ClaimsApi::ServiceBase
    LOG_TAG = 'va_notify_declined_job'

    def perform(poa_id, rep)
      return if Rails.env.test?

      poa = ClaimsApi::PowerOfAttorney.find(poa_id)

      unless poa
        raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
          detail: "Could not find Power of Attorney with id: #{poa_id}"
        )
      end

      begin
        res = send_declined_notification(poa, rep)

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

    def send_declined_notification(poa, rep)
      form_data = poa.form_data

      if form_data['serviceOrganization']
        poa_code = form_data['serviceOrganization']['poaCode']
        org = ::Veteran::Service::Organization.find_by(poa: poa_code)

        return send_organization_notification(poa, org)
      end

      send_representative_notification(poa, rep)
    end

    # TODO: Discover if we need org
    def send_organization_notification(poa, _org)
      content = {
        recipient_identifier: recipient_identifier(poa),
        personalisation: {
          first_name: poa.auth_headers['va_eauth_firstName'] || '',
          form_type: 'TODO' # TODO: Add form type, i.e., VSO or Individual
        },
        template_id: Settings.claims_api.vanotify.organization_declined_template_id
      }

      vanotify_service.send_email(content)
    end

    # TODO: Discover if we need rep
    def send_representative_notification(poa, _rep)
      content = {
        recipient_identifier: recipient_identifier(poa),
        personalisation: {
          first_name: poa.auth_headers['va_eauth_firstName'] || '',
          representative_type: poa.form_data.dig('representative', 'type') || '',
          representative_type_abbreviated: 'TODO', # TODO: Add representative type abbreviated
          form_type: 'TODO' # TODO: Add form type, i.e., VSO or Individual
        },
        template_id: Settings.claims_api.vanotify.representative_declined_template_id
      }

      vanotify_service.send_email(content)
    end

    def recipient_identifier(poa)
      poa.auth_headers[ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY]
    end

    def vanotify_service
      VaNotify::Service.new(Settings.claims_api.vanotify.services.lighthouse.api_key)
    end
  end
end
