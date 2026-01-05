# frozen_string_literal: true

module IncreaseCompensation
  ##
  # Form profile for VA Form 21-8940 (APPLICATION FOR INCREASED COMPENSATION BASED ON UNEMPLOYABILITY)
  # extends app/models/form_profile.rb, which handles form prefill
  class FormProfiles::VA218940v1 < FormProfile
    class FormAddress
      include Vets::Model

      attribute :country_name, String
      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :city, String
      attribute :state_code, String
      attribute :province, String
      attribute :zip_code, String
      attribute :international_postal_code, String
    end

    attribute :form_address, FormAddress

    ##
    # Returns metadata related to the form profile
    #
    # @return [Hash]
    def metadata
      {
        version: 0,
        prefill: true,
        returnUrl: '/confirmation-question'
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
      @contact_information = initialize_contact_information
      @identity_information = initialize_identity_information

      contact_information.email ||= user.email
      contact_information.us_phone ||= user&.home_phone&.gsub(/\D/, '')
      prefill_form_address

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

    private

    def prefill_form_address
      begin
        mailing_address = VAProfileRedis::V2::ContactInformation.for_user(user).mailing_address
      rescue
        {}
      end

      return if mailing_address.blank?

      zip_code = mailing_address.zip_code.presence || mailing_address.international_postal_code.presence
      @form_address = FormAddress.new(
        mailing_address.to_h.slice(
          :address_line1, :address_line2, :address_line3,
          :city, :state_code, :province
        ).merge(country_name: mailing_address.country_code_iso3, zip_code:)
      )
    end
  end
end
