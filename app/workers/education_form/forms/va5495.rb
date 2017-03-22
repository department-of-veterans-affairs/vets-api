# frozen_string_literal: true
module EducationForm::Forms
  class VA5495 < Base
    def school
      @applicant.newSchool
    end
  end
end
