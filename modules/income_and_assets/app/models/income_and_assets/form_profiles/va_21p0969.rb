# frozen_string_literal: true

module IncomeAndAssets
  # extends app/models/form_profile.rb, which handles form prefill
  class FormProfiles::VA21p0969 < FormProfile
    ##
    # Returns metadata related to the form profile
    #
    # @return [Hash]
    def metadata
      p 'HEREEREREREREREREERERERRERERERERERERERER'
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

      mappings = self.class.mappings_for_form(form_id)

      form_data = generate_prefill(mappings) if FormProfile.prefill_enabled_forms.include?(form_id)

      { form_data:, metadata: }
    end
  end
end
