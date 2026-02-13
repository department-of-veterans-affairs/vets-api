# frozen_string_literal: true

require 'dependents_verification/helpers'
require 'dependents_verification/monitor'

module DependentsVerification
  class DependentInformation
    include Vets::Model

    attribute :full_name, FormFullName
    attribute :date_of_birth, Date
    attribute :ssn, String
    attribute :age, Integer
    attribute :relationship_to_veteran, String
  end

  # extends app/models/form_profile.rb, which handles form prefill
  class FormProfiles::VA210538 < FormProfile
    include DependentsVerification::PrefillHelpers
    attribute :dependents_information, DependentInformation, array: true

    ##
    # Returns metadata related to the form profile
    #
    # @return [Hash]
    def metadata
      {
        version: 0,
        prefill: true,
        returnUrl: '/veteran-information'
      }
    end

    ##
    # Prefills the form data with identity, contact, and dependent information
    #
    # This method initializes identity, contact, and dependents information
    # and maps data according to form-specific mappings
    #
    # @return [Hash]
    def prefill
      begin
        @identity_information = initialize_identity_information
      rescue => e
        monitor.track_prefill_error('identity_information', e)
      end

      begin
        @contact_information = initialize_contact_information
      rescue => e
        monitor.track_prefill_error('contact_information', e)
      end

      begin
        @dependents_information = initialize_dependents_information
      rescue => e
        monitor.track_prefill_error('dependents_information', e)
      end

      mappings = self.class.mappings_for_form(form_id)

      form_data = generate_prefill(mappings) if FormProfile.prefill_enabled_forms.include?(form_id)
      { form_data:, metadata: }
    end

    ##
    # This method retrieves the dependents from the BGS service and maps them to the DependentInformation model.
    # If no dependents are found or if they are not active for benefits, it returns an empty array.
    #
    # @return [Array<DependentInformation>]
    def initialize_dependents_information
      dependents = dependent_service.get_dependents

      persons = if dependents.nil? || dependents[:persons].blank?
                  []
                else
                  dependents[:persons]
                end

      persons.filter_map do |person|
        # Skip if the dependent is not active for benefits
        next if person[:award_indicator] == 'N'

        person_to_dependent_information(person)
      end
    end

    ##
    # Assigns a dependent's information to the DependentInformation model.
    #
    # @param person [Hash] The dependent's information as a hash
    # @return [DependentInformation] The dependent's information mapped to the model
    def person_to_dependent_information(person)
      parsed_date = parse_date_safely(person[:date_of_birth])

      DependentInformation.new(
        full_name: FormFullName.new({
                                      first: person[:first_name],
                                      middle: person[:middle_name],
                                      last: person[:last_name],
                                      suffix: person[:suffix]
                                    }),
        date_of_birth: parsed_date,
        ssn: person[:ssn],
        age: parsed_date ? dependent_age(person[:date_of_birth]) : nil,
        relationship_to_veteran: person[:relationship]
      )
    end

    def dependent_service
      @dependent_service ||= BGS::DependentService.new(user)
    end

    def monitor
      @monitor ||= DependentsVerification::Monitor.new
    end
  end
end
