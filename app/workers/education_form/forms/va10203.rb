# frozen_string_literal: true

module EducationForm::Forms
  class VA10203 < Base
    def school
      @applicant.newSchool
    end

    def form_type
      'CH33'
    end

    def form_benefit
      'STEM'
    end

    def header_form_type
      '22-10203'
    end
  end
end
