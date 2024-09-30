# frozen_string_literal: true

module ClaimsApi
  class VANotifyJob < ClaimsApi::ServiceBase
    def perform(poa_id, icn_for_vanotify, rep)
      return if skip_notification_email?

      poa = ClaimsApi::PowerOfAttorney.find(poa_id)
      form_data = poa.form_data
      @icn_for_vanotify = icn_for_vanotify

      if organization_filing?(form_data)
        org = find_org(poa, '2122')

        send_organization_notification(poa, org)
      else
        poa_code_from_form('2122a', poa)

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

    # 2122a
    def send_representative_notification(poa, rep)
      vanotify_service.send_email(individual_accepted_email_contents(poa, rep))
    end

    # 2122
    def send_organization_notification(poa, org)
      vanotify_service.send_email(organization_accepted_email_contents(poa, org))
    end

    protected

    # email_address: 'rockwell.rice@oddball.io',recipient_identifier: @icn_for_vanotify
    def individual_accepted_email_contents(poa, rep)
      {
        recipient_identifier: @icn_for_vanotify,
        personalisation: {
          first_name: value_or_default_for_field(claimant_first_name(poa)),
          rep_first_name: value_or_default_for_field(rep.first_name),
          rep_last_name: value_or_default_for_field(rep.last_name),
          representative_type: value_or_default_for_field(poa_form_data(poa)&.dig('representative', 'type')),
          address1: value_or_default_for_field(poa_form_data(poa)&.dig('representative', 'address', 'addressLine1')),
          city: value_or_default_for_field(poa_form_data(poa)&.dig('representative', 'address', 'city')),
          state: value_or_default_for_field(poa_form_data(poa)&.dig('representative', 'address', 'stateCode')),
          zip: value_or_default_for_field(rep_zip(poa)),
          email: value_or_default_for_field(rep.email),
          phone: value_or_default_for_field(rep_phone(rep))
        },
        template_id: Settings.claims_api.vanotify.representative_template_id
      }
    end

    def organization_accepted_email_contents(poa, org)
      {
        recipient_identifier: @icn_for_vanotify,
        personalisation: {
          first_name: value_or_default_for_field(claimant_first_name(poa)),
          org_name: value_or_default_for_field(org.name),
          address1: value_or_default_for_field(org.address_line1),
          address2: value_or_default_for_field(org.address_line2),
          city: value_or_default_for_field(org.city),
          state: value_or_default_for_field(org.state_code),
          zip: value_or_default_for_field(org_zip(org)),
          phone: value_or_default_for_field(org.phone)
        },
        template_id: Settings.claims_api.vanotify.service_organization_template_id
      }
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
      # This field was added to adjust the values for phone numbers
      # This should the the reps specific phone number
      if rep.phone_number.present?
        rep.phone_number
      # This might be the phone number for the organization
      # the rep works for
      elsif rep.phone.present?
        rep.phone
      else
        ''
      end
    end

    def rep_zip(poa)
      first_five = poa.form_data.dig('representative', 'address', 'zipCode')
      last_four = poa.form_data.dig('representative', 'address', 'zipCodeSuffix')
      format_zip_values(first_five, last_four)
    end

    def org_zip(org)
      zip = org.zip_code
      suffx = org.zip_suffix
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

    def value_or_default_for_field(field)
      field || ''
    end

    def poa_form_data(poa)
      poa&.form_data
    end

    def claimant_first_name(poa)
      poa.auth_headers['va_eauth_firstName']
    end

    def organization_filing?(form_data)
      form_data['serviceOrganization']
    end

    def poa_code_from_form(form_number, poa)
      base = form_number == '2122' ? 'serviceOrganization' : 'representative'
      poa.form_data.dig(base, 'poaCode')
    end

    def skip_notification_email?
      Rails.env.test?
    end

    def vanotify_service
      @vanotify_service ||= VaNotify::Service.new(Settings.claims_api.vanotify.services.lighthouse.api_key)
    end
  end
end
