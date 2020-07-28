# frozen_string_literal: true

module BGSDependents
  class AdultChildAttendingSchool
    def initialize(dependents_application)
      @dependents_application = dependents_application
      @name_and_ssn = @dependents_application['student_name_and_ssn']
      @was_married = @dependents_application.dig('student_address_marriage_tuition', 'was_married')
    end

    def format_info
      {
        'ssn': @name_and_ssn['ssn'],
        'birth_date': @name_and_ssn['birth_date'],
        'ever_married_ind': @was_married == true ? 'Y' : 'N'
      }.merge(@name_and_ssn['full_name']).with_indifferent_access
    end

    def address
      @dependents_application['student_address_marriage_tuition']['address']
    end
  end
end
