# frozen_string_literal: true

module BGSDependents
  class Spouse < Base
    # The Spouse class represents a person including name, address, and marital status info
    #
    # @!attribute ssn
    #   @return [String] the person's social security number
    # @!attribute first
    #   @return [String] the person's first name
    # @!attribute middle
    #   @return [String] the person's middle name
    # @!attribute last
    #   @return [String] the person's last name
    # @!attribute suffix
    #   @return [String] the person's name suffix
    # @!attribute vet_ind
    #   @return [String] Y/N indicates whether the person is a veteran
    # @!attribute birth_date
    #   @return [String] the person's birth date
    # @!attribute address
    #   @return [Hash] the person's address
    # @!attribute va_file_number
    #   @return [String] the person's va file number
    # @!attribute ever_married_ind
    #   @return [String] Y/N indicates whether the person has ever been married
    # @!attribute martl_status_type_cd
    #   @return [String] marital status type: Married, Divorced, Widowed, Separated, Never Married
    # @!attribute spouse_income
    #   @return [String] did this spouse have income in the last 365 days
    #
    attribute :ssn, String
    attribute :first, String
    attribute :middle, String
    attribute :last, String
    attribute :suffix, String
    attribute :vet_ind, String
    attribute :birth_date, String
    attribute :address, Hash
    attribute :va_file_number, String
    attribute :ever_married_ind, String
    attribute :martl_status_type_cd, String
    attribute :spouse_income, String

    def initialize(dependents_application)
      @dependents_application = dependents_application
      @spouse_information = @dependents_application['spouse_information']

      assign_attributes
    end

    # Sets a hash with spouse attributes
    #
    # @return [Hash] spouse attributes including name, address and marital info
    #
    def format_info
      attributes.with_indifferent_access
    end

    private

    def assign_attributes
      @ssn = @spouse_information['ssn']
      @birth_date = @spouse_information['birth_date']
      @ever_married_ind = 'Y'
      @martl_status_type_cd = marital_status
      @vet_ind = spouse_is_veteran
      @address = spouse_address
      @spouse_income = spouse_income
      @first = @spouse_information['full_name']['first']
      @middle = @spouse_information['full_name']['middle']
      @last = @spouse_information['full_name']['last']
      @suffix = @spouse_information['full_name']['suffix']
      @va_file_number = @spouse_information['va_file_number'] if spouse_is_veteran == 'Y'
    end

    def lives_with_vet
      @dependents_application['does_live_with_spouse']['spouse_does_live_with_veteran']
    end

    def spouse_is_veteran
      @spouse_information['is_veteran'] ? 'Y' : 'N'
    end

    def marital_status
      lives_with_vet ? 'Married' : 'Separated'
    end

    def spouse_income
      if @dependents_application['does_live_with_spouse']['spouse_income'] == 'NA'
        nil
      else
        @dependents_application['does_live_with_spouse']['spouse_income']
      end
    end

    def spouse_address
      dependent_address(
        dependents_application: @dependents_application,
        lives_with_vet: @dependents_application['does_live_with_spouse']['spouse_does_live_with_veteran'],
        alt_address: @dependents_application.dig('does_live_with_spouse', 'address')
      )
    end

    # temporarily not used until rbps can handle it in the payload
    def marriage_method_name
      @dependents_application.dig('current_marriage_information', 'type_of_marriage')
    end
  end
end
