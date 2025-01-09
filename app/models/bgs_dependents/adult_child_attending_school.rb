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
    attribute :dependent_income, String

    validates :first, presence: true
    validates :last, presence: true

    def initialize(dependents_application)
      @dependents_application = dependents_application
      @is_v2 = Flipper.enabled?(:va_dependents_v2)
      # with v2 handling, dependents_application is one to many hashes within the student_information array
      @source = @is_v2 ? @dependents_application : @dependents_application.dig('student_name_and_ssn')
      @ssn = @source.dig('ssn')
      @full_name = @source.dig('full_name')
      @birth_date = @source.dig('birth_date')
      @was_married = @source.dig('was_married')
      @dependent_income = @source.dig('student_income')

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
      @source['address']
    end

    private

    def described_class_attribute_hash
      # we will raise an error here if not #valid? when we merge in exception PR

      {
        ssn: @ssn,
        birth_date: @birth_date,
        ever_married_ind: formatted_boolean(@was_married),
        dependent_income: formatted_boolean(@dependent_income)
      }.merge(@full_name)
    end
  end
end
