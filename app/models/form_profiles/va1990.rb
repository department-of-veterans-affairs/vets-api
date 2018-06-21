# frozen_string_literal: true

class FormProfiles::VA1990 < FormProfile
  def prefill(user)
    return_val = super
    form_data = return_val[:form_data]

    if Settings.vet360.prefill
      contact_information = Vet360Redis::ContactInformation.for_user(user)

      {
        'homePhone' => 'home_phone',
        'mobilePhone' => 'mobile_phone',
        'email' => 'email'
      }.each do |k, method|
        value = contact_information.public_send(method)
        form_data[k] = value if value.present?
      end

      form_data['veteranAddress'] = convert_vets360_address(contact_information.mailing_address) if contact_information.mailing_address.present?
    end
    return_val
  end

  def convert_vets360_phone(phone)
    phone_number = phone.phone_number
    return if phone_number.blank?

  end

  def convert_vets360_address(address)
    {
      'street' => address.address_line1,
      'street2' => address.address_line2,
      'city' => address.city,
      'state' => address.state_code || address.province,
      'country' => address.country_code_iso3,
      'postalCode' => address.zip_plus_four || address.international_postal_code
    }
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end
end
