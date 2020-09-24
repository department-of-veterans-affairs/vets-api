# frozen_string_literal: true

module BGSDependents
  class AdultChildAttendingSchool < Base
    # The AdultChildAttendingSchool class represents a person including name and address info
    #
    # @!attribute first
    #   @return [String] the person's first name
    # @!attribute middle
    #   @return [String] the person's middle name
    # @!attribute last
    #   @return [String] the person's last name
    # @!attribute suffix
    #   @return [String] the person's name suffix
    # @!attribute ssn
    #   @return [String] the person's social security number
    # @!attribute birth_date
    #   @return [String] the person's birth date
    # @!attribute ever_married_ind
    #   @return [String] Y/N indicates whether the person has ever been married
    #
    attribute :first, String
    attribute :middle, String
    attribute :last, String
    attribute :suffix, String
    attribute :ssn, String
    attribute :birth_date, String
    attribute :ever_married_ind, String

    validates :first, presence: true
    validates :last, presence: true

    def initialize(dependents_application)
      @dependents_application = dependents_application
      @ssn = @dependents_application.dig('student_name_and_ssn', 'ssn')
      @full_name = @dependents_application['student_name_and_ssn']['full_name']
      @birth_date = @dependents_application.dig('student_name_and_ssn', 'birth_date')
      @was_married = @dependents_application['student_address_marriage_tuition']['was_married']

      self.attributes = described_class_attribute_hash
    end

    # Sets a hash with AdultChildAttendingSchool attributes
    #
    # @return [Hash] AdultChildAttendingSchool attributes including name and address info
    #
    def format_info
      attributes.with_indifferent_access
    end

    # Sets a hash with the student's address based on the submitted form information
    #
    # @return [Hash] the student's address
    #
    def address
      @dependents_application['student_address_marriage_tuition']['address']
    end

    private

    def described_class_attribute_hash
      # we will raise an error here if not #valid? when we merge in exception PR

      {
        ssn: @ssn,
        birth_date: @birth_date,
        ever_married_ind: @was_married == true ? 'Y' : 'N'
      }.merge(@full_name)
    end
  end
end
