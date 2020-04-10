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
      'STEM1995'
    end
  end
end