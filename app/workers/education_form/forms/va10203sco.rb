# frozen_string_literal: true

module EducationForm::Forms
  class VA10203SCO < Base
    def header_form_type
      'V10203'
    end

    def format
      super('10203sco')
    end
  end
end
