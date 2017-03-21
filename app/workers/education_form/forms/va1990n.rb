# frozen_string_literal: true
module EducationForm::Forms
  class VA1990n < Base
    def school
      @applicant.educationProgram
    end

    def non_va_assistance
      @applicant.currentlyActiveDuty&.nonVaAssistance
    end
  end
end
