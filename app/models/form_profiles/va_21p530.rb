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
    @identity_information = initialize_identity_information
    @contact_information = initialize_contact_information
    @contact_information.address.country = convert_to_iso2(@contact_information.address.country)
    @military_information = initialize_military_information
    mappings = self.class.mappings_for_form(form_id)

    form_data = generate_prefill(mappings) if FormProfile.prefill_enabled_forms.include?(form_id)

    { form_data: form_data, metadata: metadata }
  end

  private

  def convert_to_iso2(country_code)
    code = IsoCountryCodes.find(country_code)
    code.alpha2
  end
end
