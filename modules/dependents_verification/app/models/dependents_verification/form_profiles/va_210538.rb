# frozen_string_literal: true

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

    def hyphenated_ssn
      StringHelpers.hyphenated_ssn(ssn)
    end

    def ssn_last_four
      ssn.last(4)
    end
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
      @identity_information = initialize_identity_information
      @contact_information = initialize_contact_information
      @dependents_information = initialize_dependents_information

      mappings = self.class.mappings_for_form(form_id)

      form_data = generate_prefill(mappings) if FormProfile.prefill_enabled_forms.include?(form_id)
      puts form_data
      { form_data:, metadata: }
    end

    def initialize_dependents_information
      dependents = dependent_service.get_dependents
      dependents[:diaries] = dependency_verification_service.read_diaries
      dependents[:persons].map do |person|
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
      puts user
      @dependent_service ||= if Flipper.enabled?(:va_dependents_v2, user)
                               BGS::DependentV2Service.new(user)
                             else
                               BGS::DependentService.new(user)
                             end
    end

    def dependency_verification_service
      @dependency_verification_service ||= BGS::DependencyVerificationService.new(user)
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
