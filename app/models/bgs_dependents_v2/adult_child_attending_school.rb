# frozen_string_literal: true

module BGSDependentsV2
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

    def initialize(dependents_application) # rubocop:disable Lint/MissingSuper
      @source = dependents_application
      @ssn = @source['ssn']
      @full_name = @source['full_name']
      @birth_date = @source['birth_date']
      @was_married = @source['was_married']
      @ever_married_ind = formatted_boolean(@was_married)
      @dependent_income = formatted_boolean(@source['student_income'])
      @first = @full_name['first']
      @middle = @full_name['middle']
      @last = @full_name['last']
      @suffix = @full_name['suffix']
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
  end
end
