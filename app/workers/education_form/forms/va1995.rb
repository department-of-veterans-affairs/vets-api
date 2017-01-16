module EducationForm::Forms
  class VA1995 < Base
    TYPE = '22-1995'

    def school
      @applicant.newSchool
    end
  end
end
