# frozen_string_literal: true

require 'iso_country_codes'

module Burials
  # extends app/models/form_profile.rb, which handles form prefill
  class FormProfiles::VA21p530ez < FormProfile
    ##
    # Returns metadata related to the form profile
    #
    # @return [Hash]
    def metadata
      {
        version: 0,
        prefill: true,
        returnUrl: '/claimant-information'
      }
    end

    ##
    # Prefills the form data with identity and contact information
    #
    # This method initializes identity and contact information, converts the country code
    # to ISO2 format if present, and maps data according to form-specific mappings
    #
    # @return [Hash]
    def prefill
      @identity_information = initialize_identity_information
      @contact_information = initialize_contact_information
      if @contact_information&.address&.country.present?
        @contact_information.address.country = convert_to_iso2(@contact_information.address.country)
      end

      mappings = self.class.mappings_for_form(form_id)

      form_data = generate_prefill(mappings) if FormProfile.prefill_enabled_forms.include?(form_id)

      { form_data:, metadata: }
    end

    private

    ##
    # Converts a country code to ISO2 format
    #
    # @param country_code [String]
    # @return [String]
    def convert_to_iso2(country_code)
      code = IsoCountryCodes.find(country_code)
      code.alpha3
    end
  end
end
