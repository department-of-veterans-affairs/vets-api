# frozen_string_literal: true

module IncreaseCompensation
  ##
  # Form profile for VA Form 21-8940 (APPLICATION FOR INCREASED COMPENSATION BASED ON UNEMPLOYABILITY)
  # extends app/models/form_profile.rb, which handles form prefill
  class FormProfiles::VA218940v1 < FormProfile
    ##
    # Returns metadata related to the form profile
    #
    # @return [Hash]
    def metadata
      {
        version: 0,
        prefill: true,
        returnUrl: '/introduction'
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
      contact_information.email ||= user.email
      contact_information.us_phone ||= user&.home_phone&.gsub(/\D/, '')

      mappings = self.class.mappings_for_form(form_id)

      form_data = generate_prefill(mappings) if FormProfile.prefill_enabled_forms.include?(form_id)

      { form_data:, metadata: }
    end

    ##
    # Retrieves the last four digits of the VA file number or SSN from BGS
    #
    # @return [String]
    def va_file_number
      response = BGS::People::Request.new.find_person_by_participant_id(user:)
      response.file_number.presence || user.ssn.presence
    end
  end
end
