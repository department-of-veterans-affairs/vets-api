# frozen_string_literal: true
module EducationForm::Forms
  class VA1990e < Base
    TYPE = '22-1990e'

    def header_form_type
      'E1990'
    end

    def benefit_type(application)
      application.benefit.gsub('chapter', 'CH')
    end
  end
end
