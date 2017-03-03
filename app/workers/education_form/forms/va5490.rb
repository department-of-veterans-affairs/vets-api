# frozen_string_literal: true
module EducationForm::Forms
  class VA5490 < Base
    def applicant_name
      @applicant.relativeFullName
    end

    def applicant_ssn
      @applicant.relativeSocialSecurityNumber
    end

    def school
      @applicant.educationProgram
    end

    def high_school_status
      key = {
        'graduated' => 'Graduated from high school',
        'discontinued' => 'Discontinued high school',
        'graduationExpected' => 'Expect to graduate from high school',
        'ged' => 'Awarded GED',
        'neverAttended' => 'Never attended high school'
      }

      status = @applicant.highSchool&.status
      return if status.nil?

      key[status]
    end
  end
end
