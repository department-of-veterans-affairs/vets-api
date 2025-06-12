# frozen_string_literal: true

require 'dependents_verification/monitor'

module DependentsVerification
  class DependentInformation
    include Vets::Model

    attribute :full_name, FormFullName
    attribute :date_of_birth, Date
    attribute :ssn, String
    attribute :age, Integer
    attribute :relationship_to_veteran, String
    attribute :removal_date, Date
    attribute :enrollment_type, String
  end

  # extends app/models/form_profile.rb, which handles form prefill
  class FormProfiles::VA210538 < FormProfile
    attribute :dependents_information, Array[DependentInformation]

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
    # Prefills the form data with identity and contact information
    #
    # This method initializes identity and contact information and maps data according to form-specific mappings
    #
    # @return [Hash]
    def prefill
      monitor = DependentsVerification::Monitor.new
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

    def initialize_dependents_information
      dependents = dependent_service.get_dependents

      return [] if dependents.nil? || dependents[:persons].blank?

      dependents[:persons].filter_map do |person|
        # Skip if the dependent is not active for benefits
        return nil if person[:award_indicator] == 'N'

        DependentInformation.new(
          full_name: FormFullName.new({
                                        first: person[:first_name],
                                        middle: person[:middle_name],
                                        last: person[:last_name],
                                        suffix: person[:suffix]
                                      }),
          date_of_birth: person[:date_of_birth],
          ssn: person[:ssn],
          age: dependent_age(person[:date_of_birth]),
          relationship_to_veteran: person[:relationship],
          removal_date: nil,
          enrollment_type: nil
        )
      end
    end

    def dependent_service
      @dependent_service ||= BGS::DependentService.new(user)
    end

    ##
    # Calculates the age of a dependent based on their date of birth
    #
    # @param date_of_birth [String] The date of birth of the dependent
    # @return [Integer] The age of the dependent
    def dependent_age(date_of_birth)
      return nil if date_of_birth.blank?

      dob = Date.parse(date_of_birth)
      now = Time.now.utc.to_date

      # If the current month is greater than the birth month,
      # or if it's the same month but the current day is greater than or equal to the birth day,
      # then the birthday has occurred this year.
      # Otherwise, subtract one year additional year from the age.
      after_birthday = now.month > dob.month || (now.month == dob.month && now.day >= dob.day)
      now.year - dob.year - (after_birthday ? 0 : 1)
    end
  end
end
