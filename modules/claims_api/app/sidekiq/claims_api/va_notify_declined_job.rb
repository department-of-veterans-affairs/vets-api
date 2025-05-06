# frozen_string_literal: true

module ClaimsApi
  class VANotifyDeclinedJob < ClaimsApi::ServiceBase
    LOG_TAG = 'va_notify_declined_job'

    def perform(encrypted_ptcpnt_id, encrypted_first_name, representative_id)
      lockbox = Lockbox.new(key: Settings.lockbox.master_key)
      ptcpnt_id = lockbox.decrypt(Base64.strict_decode64(encrypted_ptcpnt_id))
      first_name = lockbox.decrypt(Base64.strict_decode64(encrypted_first_name))
      representative = ::Veteran::Service::Representative.find_by(representative_id:)

      if representative.blank?
        raise ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
          detail: "Could not find veteran representative with id: #{representative_id}"
        )
      end

      res = send_declined_notification(ptcpnt_id:, first_name:, representative:)

      ClaimsApi::VANotifyFollowUpJob.perform_async(res.id) if res.present?
    rescue => e
      msg = "VA Notify email notification failed to send with error #{e}"
      ClaimsApi::Logger.log(LOG_TAG, detail: msg)
      slack_alert_on_failure('ClaimsApi::VANotifyDeclinedJob', msg)
      raise e
    end

    private

    def find_poa(poa_code:)
      ClaimsApi::PowerOfAttorney.find do |poa|
        poa.form_data.dig('serviceOrganization', 'poaCode') == poa_code ||
          poa.form_data.dig('representative', 'poaCode') == poa_code
      end
    end

    def send_declined_notification(ptcpnt_id:, first_name:, representative:)
      representative_type = representative.user_type
      return send_organization_notification(ptcpnt_id:, first_name:) if representative_type == 'veteran_service_officer'

      send_representative_notification(ptcpnt_id:, first_name:, representative_type:)
    end

    def send_organization_notification(ptcpnt_id:, first_name:)
      content = {
        recipient_identifier: {
          id_type: 'PID',
          id_value: ptcpnt_id
        },
        personalisation: {
          first_name: first_name || '',
          form_type: 'Appointment of Veterans Service Organization as Claimantʼs Representative (VA Form 21-22)'
        },
        template_id: Settings.claims_api.vanotify.declined_service_organization_template_id
      }

      vanotify_service.send_email(content)
    end

    def send_representative_notification(ptcpnt_id:, first_name:, representative_type:)
      representative_type_text = get_representative_type_text(representative_type:)

      content = {
        recipient_identifier: {
          id_type: 'PID',
          id_value: ptcpnt_id
        },
        personalisation: {
          first_name: first_name || '',
          representative_type: representative_type_text || 'representative',
          representative_type_abbreviated: representative_type_text || 'representative',
          form_type: 'Appointment of Individual as Claimantʼs Representative (VA Form 21-22a)'
        },
        template_id: Settings.claims_api.vanotify.declined_representative_template_id
      }

      vanotify_service.send_email(content)
    end

    def get_representative_type_text(representative_type:)
      case representative_type
      when 'attorney'
        'attorney'
      when 'claim_agents'
        'claims agent'
      end
    end

    def vanotify_service
      VaNotify::Service.new(Settings.claims_api.vanotify.services.lighthouse.api_key)
    end
  end
end
