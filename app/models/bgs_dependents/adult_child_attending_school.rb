# frozen_string_literal: true

module BGSDependents
  class AdultChildAttendingSchool < Base
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
      @was_married = @dependents_application['student_address_marriage_tuition']['was_married']
      @name_and_ssn = @dependents_application['student_name_and_ssn']

      self.attributes = child_attributes
    end

    def format_info
      attributes.with_indifferent_access
    end

    def address
      @dependents_application['student_address_marriage_tuition']['address']
    end

    private

    def child_attributes
      # we will raise an error here if not #valid? when we merge in exception PR

      {
        ssn: @name_and_ssn['ssn'],
        birth_date: @name_and_ssn['birth_date'],
        ever_married_ind: @was_married == true ? 'Y' : 'N'
      }.merge(@name_and_ssn['full_name'])
    end
  end
end
