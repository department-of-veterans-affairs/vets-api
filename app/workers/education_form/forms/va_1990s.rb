# frozen_string_literal: true

module EducationForm::Forms
  class VA1990s < Base
    def header_form_type
      '1990S'
    end

    LEARNING_FORMAT = {
      'inPerson': 'In person',
      'online': 'Online',
      'onlineAndInPerson': 'Online and in person'
    }.freeze

    def location
      return '' if @applicant.providerName.blank?

      "#{@applicant.programCity}, #{@applicant.programState}"
    end
  end
end
