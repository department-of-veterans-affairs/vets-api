# frozen_string_literal: true

module ClaimsApi
  class PoaUpdateVANotifyJob < ClaimsApi::ServiceBase
    def perform(poa_id)
      return if skip_notification_email?

      poa = ClaimsApi::PowerOfAttorney.find(poa_id)
      form_data = poa.form_data

      if organization_filing?(form_data)
        org = find_org(poa, '2122')

        send_organization_notification(poa, org)
      else
        poa_code = poa_code_from_form('2122a', poa)
        rep = ::Veteran::Service::Representative.where('? = ANY(poa_codes) AND representative_id = ?',
                                                       poa_code,
                                                       rep_registration_number(poa)).order(created_at: :desc).first

        send_representative_notification(poa, rep)
      end
    rescue => e
      ClaimsApi::Logger.log(
        'poa_update_notify_job',
        retry: true,
        detail: "Failed to notify with error: #{get_error_message(e)}"
      )

      raise e
    end

    protected

    # 2122a
    def send_representative_notification(poa, rep)
      vanotify_service.send_email(
        {
          recipient_identifier: 'rockwell.rice@oddball.io',
          personalisation: {
            first_name: claimant_first_name(poa),
            rep_first_name: rep['first_name'],
            rep_last_name: rep['last_name'],
            representative_type: poa&.form_data&.dig('representative', 'type'),
            org_name: find_org(poa, '2122a').name,
            address1: poa&.form_data&.dig('representative', 'address', 'addressLine1'),
            address2: poa&.form_data&.dig('representative', 'address', 'addressLine2'),
            city: poa&.form_data&.dig('representative', 'address', 'city'),
            state: poa&.form_data&.dig('representative', 'address', 'stateCode'),
            zip: rep_zip(poa),
            email: rep['email'],
            phone: rep_phone(rep)
          },
          template_id: Settings.claims_api.vanotify.representative_template_id
        }
      )
    end

    # 2122
    def send_organization_notification(poa, org)
      vanotify_service.send_email(
        {
          recipient_identifier: 'rockwell.rice@oddball.io',
          personalisation: {
            first_name: claimant_first_name(poa),
            org_name: org['name'],
            address1: org['address_line1'],
            address2: org['address_line2'],
            city: org['city'],
            state: org['state_code'],
            zip: org_zip(org),
            email: org_email(poa),
            phone: org['phone']
          },
          template_id: Settings.claims_api.vanotify.service_organzation_template_id
        }
      )
    end

    def find_org(poa, form_number)
      poa_code = poa_code_from_form(form_number, poa)
      ::Veteran::Service::Organization.find_by(poa: poa_code)
    end

    def veteran_icn_identfier(poa)
      poa.source_data&.dig('source_data', 'icn')
    end

    def rep_registration_number(poa)
      poa.form_data.dig('representative', 'registrationNumber')
    end

    def rep_phone(rep)
      rep['phone']
    end

    def rep_zip(poa)
      first_five = poa.form_data.dig('representative', 'address', 'zipFirstFive')
      last_four = poa.form_data.dig('representative', 'address', 'zipLastFour')
      format_zip_values(first_five, last_four)
    end

    def org_zip(org)
      zip = org['zip_code']
      suffx = org['zip_suffix']
      format_zip_values(zip, suffx)
    end

    def format_zip_values(first, last)
      # neither are required for either form
      if first && last
        "#{first}-#{last}"
      elsif first && !last
        first
      elsif !first && last
        last
      end
    end

    def claimant_first_name(poa)
      poa.auth_headers['va_eauth_firstName']
    end

    def org_email(poa)
      poa.form_data.dig('serviceOrganization', 'email')
    end

    def organization_filing?(form_data)
      form_data.dig('data', 'attributes', 'serviceOrganization')
    end

    def poa_code_from_form(form_number, poa)
      base = form_number == '2122' ? 'serviceOrganization' : 'representative'
      poa.form_data.dig('data', 'attributes', base, 'poaCode')
    end

    def skip_notification_email?
      Rails.env.test?
    end

    def vanotify_service
      @vanotify_service ||= VaNotify::Service.new(Settings.claims_api.vanotify.services.lighthouse.api_key)
    end
  end
end
