# frozen_string_literal: true

module EducationForm::Forms
  class VA1990e < Base
    def header_form_type
      'E1990'
    end

    def school
      @applicant.educationProgram
    end

    def applicant_name
      @applicant.relativeFullName
    end

    def non_va_assistance
      @applicant.nonVaAssistance
    end

    def applicant_ssn
      @applicant.relativeSocialSecurityNumber
    end
  end
end
