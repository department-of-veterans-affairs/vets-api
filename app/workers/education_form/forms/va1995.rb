# frozen_string_literal: true

module EducationForm::Forms
  class VA1995 < Base
    FORM_TYPES = {
      'chapter30': 'CH30',
      'chapter32': 'CH32',
      'chapter33': 'CH33',
      'chapter1606': 'CH1606',
      'chapter1607': 'CH1607',
      'transferOfEntitlement': 'TransferOfEntitlement'
    }.freeze

    def school
      @applicant.newSchool
    end

    def form_type(applicant)
      return 'STEM' if applicant.isEdithNourseRogersScholarship
      FORM_TYPES[applicant.benefit&.to_sym]
    end

    def form_benefit(applicant)
      return 'STEM' if applicant.isEdithNourseRogersScholarship
      applicant.benefit&.titleize
    end
  end
end
