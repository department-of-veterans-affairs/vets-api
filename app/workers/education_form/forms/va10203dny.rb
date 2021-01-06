# frozen_string_literal: true

module EducationForm::Forms
  class VA10203dny < EducationForm::VA10203
    self.table_name = 'va10203dny'

    def header_form_type
      'V10203DNY'
    end
  end
end
