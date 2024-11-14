# frozen_string_literal: true

module ClaimsApi
  class VANotifyDeclinedJob < ClaimsApi::ServiceBase
    LOG_TAG = 'va_notify_declined_job'

    def perform(encrypted_ptcpnt_id:, encrypted_first_name:, poa_code:)
      lockbox = Lockbox.new(key: Settings.lockbox.master_key)
      ptcpnt_id = lockbox.decrypt(encrypted_ptcpnt_id)
      first_name = lockbox.decrypt(encrypted_first_name)
      poa = find_poa(poa_code:)

      if poa.blank?
        raise ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
          detail: "Could not find Power of Attorney with POA code: #{poa_code}"
        )
      end

      res = send_declined_notification(ptcpnt_id:, first_name:, poa:)

      ClaimsApi::VANotifyFollowUpJob.perform_async(res.id) if res.present?
    rescue => e
      msg = "VA Notify email notification failed to send with error #{e}"
      slack_client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                             channel: '#api-benefits-claims-alerts',
                                             username: 'Failed ClaimsApi::VANotifyDeclinedJob')

      slack_client.notify(msg)
      ClaimsApi::Logger.log(LOG_TAG, detail: msg)

      raise e
    end

    private

    def find_poa(poa_code:)
      ClaimsApi::PowerOfAttorney.find do |poa|
        poa.form_data.dig('serviceOrganization', 'poaCode') == poa_code ||
          poa.form_data.dig('representative', 'poaCode') == poa_code
      end
    end

    def send_declined_notification(ptcpnt_id:, first_name:, poa:)
      return send_organization_notification(ptcpnt_id:, first_name:) if poa.form_data['serviceOrganization'].present?

      send_representative_notification(ptcpnt_id:, first_name:, poa:)
    end

    def send_organization_notification(ptcpnt_id:, first_name:)
      content = {
        recipient_identifier: ptcpnt_id,
        personalisation: {
          first_name: first_name || '',
          form_type: 'Appointment of Veterans Service Organization as Claimantʼs Representative (VA Form 21-22)'
        },
        template_id: Settings.claims_api.vanotify.declined_service_organization_template_id
      }

      vanotify_service.send_email(content)
    end

    def send_representative_notification(ptcpnt_id:, first_name:, poa:)
      representative_type = poa.form_data.dig('representative', 'type')

      content = {
        recipient_identifier: ptcpnt_id,
        personalisation: {
          first_name: first_name || '',
          representative_type: representative_type || '',
          representative_type_abbreviated: representative_type_abbreviated(representative_type),
          form_type: 'Appointment of Individual as Claimantʼs Representative (VA Form 21-22a)'
        },
        template_id: Settings.claims_api.vanotify.declined_representative_template_id
      }

      vanotify_service.send_email(content)
    end

    def representative_type_abbreviated(representative_type)
      representative_type == 'Veteran Service Organization (VSO)' ? 'VSO' : representative_type
    end

    def vanotify_service
      VaNotify::Service.new(Settings.claims_api.vanotify.services.lighthouse.api_key)
    end
  end
end
