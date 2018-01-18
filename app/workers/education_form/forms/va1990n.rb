# frozen_string_literal: true

module EducationForm::Forms
  class VA1990n < Base
    def header_form_type
      'N1990'
    end

    def school
      @applicant.educationProgram
    end

    def non_va_assistance
      @applicant.currentlyActiveDuty&.nonVaAssistance
    end
  end
end
