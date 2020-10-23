# frozen_string_literal: true

require 'iso_country_codes'

class FormProfiles::VA21p530 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/claimant-information'
    }
  end

  def prefill
    super
    @contact_information.address.country = if vet360_mailing_address.present?
      vet360_mailing_address.country_code_iso2
    else
      convert_to_iso2(va_profile_address_hash.country)
    end
  end

  private

  def convert_to_iso2(country_code)
    code = IsoCountryCodes.find(country_code)
    code.alpha2
  end
end
