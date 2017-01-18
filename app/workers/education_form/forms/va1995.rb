# frozen_string_literal: true
module EducationForm::Forms
  class VA1995 < Base
    TYPE = '22-1995'

    def school
      @applicant.newSchool
    end

    def full_name
      name = @applicant.veteranFullName
      return '' if name.nil?
      [name.last, name.first, name.middle].compact.join(' ')
    end
  end
end
