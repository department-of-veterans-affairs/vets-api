# frozen_string_literal: true

module EducationForm::Forms
  class VA1995 < Base
    FORM_TYPES = {
      chapter30: 'CH30',
      chapter32: 'CH32',
      chapter33: 'CH33',
      chapter33Post911: 'CH33',
      chapter33FryScholarship: 'CH33',
      chapter35: 'CH35',
      chapter1606: 'CH1606',
      chapter1607: 'CH1607',
      transferOfEntitlement: 'TransferOfEntitlement'
    }.freeze

    def school
      @applicant.newSchool
    end

    def header_abbreviated_form_type(header_form_type)
      return 'CH33' if header_form_type.eql?('transferOfEntitlement')

      FORM_TYPES[header_form_type&.to_sym]
    end

    def form_type
      FORM_TYPES[@applicant.benefit&.to_sym]
    end

    def form_benefit
      @applicant.benefitUpdate&.titleize
    end

    def header_form_type
      @applicant.rudisillReview == 'Yes' ? '1995R' : 'V1995'
    end
  end
end
