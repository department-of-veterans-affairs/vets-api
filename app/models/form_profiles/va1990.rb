# frozen_string_literal: true

class FormProfiles::VA1990 < FormProfile
  include BetaSwitch

  def prefill(user)
    # TODO: temporary solution for vets360 testing, move code to `FormContactInformation` in the future
    return_val = super

    if Settings.vet360.prefill && beta_enabled?(user.uuid, FormProfile::V360_PREFILL_KEY)
      form_data = return_val[:form_data]
      contact_information = Vet360Redis::ContactInformation.for_user(user)
      email = contact_information.email&.email_address

      if contact_information.mailing_address.present?
        form_data['veteranAddress'] = convert_vets360_address(contact_information.mailing_address)
      end
      %w[home mobile].each do |type|
        phone = contact_information.public_send("#{type}_phone")&.formatted_phone
        form_data["#{type}Phone"] = phone if phone.present?
      end
      form_data['email'] = email if email.present?
    end

    return_val
  end

  def convert_vets360_address(address)
    {
      'street' => address.address_line1,
      'street2' => address.address_line2,
      'city' => address.city,
      'state' => address.state_code || address.province,
      'country' => address.country_code_iso3,
      'postalCode' => address.zip_plus_four || address.international_postal_code
    }.compact
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end
end
