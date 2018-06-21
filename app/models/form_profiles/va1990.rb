# frozen_string_literal: true

class FormProfiles::VA1990 < FormProfile
  def prefill(user)
    return_val = super

    if Settings.vet360.prefill
      contact_information = Vet360Redis::ContactInformation.for_user(user)

      {
        'homePhone' => 'home_phone',
      }

      return_val[:form_data]['homePhone'] = contact_information.home_phone if contact_information.home_phone.present?
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
      'postalCode' => sdf
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
