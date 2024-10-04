# frozen_string_literal: true

module ClaimsApi
  class VANotifyJob < ClaimsApi::ServiceBase
    def perform(poa_id, rep)
      return if skip_notification_email?

      poa = ClaimsApi::PowerOfAttorney.find(poa_id)
      unless poa
        raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
          detail: "Could not find Power of Attorney with id: #{poa_id}"
        )
      end

      if organization_filing?(poa.form_data)
        org = find_org(poa, '2122')
        send_organization_notification(poa, org)
      else
        poa_code_from_form('2122a', poa)
        send_representative_notification(poa, rep)
      end
    rescue => e
      ClaimsApi::Logger.log(
        'poa_update_notify_job',
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

    private

    def individual_accepted_email_contents(poa, rep)
      {
        recipient_identifier: icn_for_vanotify(poa.auth_headers),
        personalisation: {
          first_name: value_or_default_for_field(claimant_first_name(poa)),
          rep_first_name: value_or_default_for_field(rep.first_name),
          rep_last_name: value_or_default_for_field(rep.last_name),
          representative_type: value_or_default_for_field(poa.form_data.dig('representative', 'type')),
          address: value_or_default_for_field(build_ind_poa_address(poa)),
          location: value_or_default_for_field(rep_location(poa)),
          email: value_or_default_for_field(rep.email),
          phone: rep_phone(rep)
        },
        template_id: Settings.claims_api.vanotify.representative_template_id
      }
    end

    def organization_accepted_email_contents(poa, org)
      {
        recipient_identifier: icn_for_vanotify(poa.auth_headers),
        personalisation: {
          first_name: value_or_default_for_field(claimant_first_name(poa)),
          org_name: value_or_default_for_field(org.name),
          address: build_org_address(org),
          location: value_or_default_for_field(org_location(org)),
          phone: value_or_default_for_field(org.phone)
        },
        template_id: Settings.claims_api.vanotify.service_organization_template_id
      }
    end

    def find_org(poa, form_number)
      poa_code = poa_code_from_form(form_number, poa)
      ::Veteran::Service::Organization.find_by(poa: poa_code)
    end

    def rep_phone(rep)
      # This field was added to adjust the values for phone numbers
      # This should be the the reps specific phone number
      if rep.phone_number.present?
        rep.phone_number
      # This might be the phone number for the organization
      # the rep works for so using it as a fallback preferring the first
      elsif rep.phone.present?
        rep.phone
      else
        ''
      end
    end

    def rep_location(poa)
      address = poa.form_data.dig('representative', 'address')
      city = address['city']
      state = address['stateCode']
      zip = rep_zip(address)

      build_location(city, state, zip)
    end

    def org_location(org)
      city = org.city
      state_or_province = org.state_code || org.state || org.province
      zip = org_zip(org)

      build_location(city, state_or_province, zip)
    end

    def build_location(city, state_or_province, zip)
      location = [city, state_or_province].compact_blank.join(', ')
      [location, zip].compact_blank.join(' ')
    end

    def rep_zip(address)
      first_five = address['zipCode']
      last_four = address['zipCodeSuffix']

      format_zip_values(first_five, last_four)
    end

    def org_zip(org)
      zip = org.zip_code
      suffx = org.zip_suffix

      format_zip_values(zip, suffx)
    end

    def format_zip_values(first, last)
      # neither are required for either form
      [first, last].compact_blank.join('-')
    end

    # we need to send empty string, nil causes an error to be returned
    def value_or_default_for_field(field)
      field || ''
    end

    def icn_for_vanotify(auth_headers)
      auth_headers[ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY]
    end

    def build_ind_poa_address(poa)
      form_data = poa&.form_data
      address_line1 = form_data&.dig('representative', 'address', 'addressLine1')
      address_line2 = form_data&.dig('representative', 'address', 'addressLine2')
      address_line3 = form_data&.dig('representative', 'address', 'addressLine3')

      build_address(address_line1, address_line2, address_line3)
    end

    def build_org_address(org)
      address_line1 = org.address_line1
      address_line2 = org.address_line2
      address_line3 = org.address_line3

      build_address(address_line1, address_line2, address_line3)
    end

    def build_address(line1, line2, line3)
      [line1, line2, line3].compact_blank.join("\n ")
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
