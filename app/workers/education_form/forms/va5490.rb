# frozen_string_literal: true
module EducationForm::Forms
  class VA5490 < Base
    def applicant_name
      @applicant.relativeFullName
    end
  end
end
