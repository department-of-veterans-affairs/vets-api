# frozen_string_literal: true

module EducationForm::Forms
  class VA5495 < Base
    def school
      @applicant.educationProgram
    end

    def applicant_name
      @applicant.relativeFullName
    end

    def applicant_ssn
      @applicant.relativeSocialSecurityNumber
    end
  end
end
