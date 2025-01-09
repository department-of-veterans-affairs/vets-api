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

    def initialize(student_info)
      @student_info = student_info
      @ssn = student_info.dig('ssn')
      @full_name = student_info['full_name']
      @birth_date = student_info.dig('birth_date')
      @was_married = student_info['was_married']
      @dependent_income = student_info['student_income']

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
      @student_info['address']
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
