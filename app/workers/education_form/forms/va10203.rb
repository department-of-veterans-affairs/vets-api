# frozen_string_literal: true

module EducationForm::Forms
  class VA10203 < Base
    def header_form_type
      return 'STEM1995' unless Flipper.enabled?(:stem_document_type)

      'V10203'
    end

    def form_benefit
      @applicant.benefit&.titleize
    end

    def school_name
      @applicant.schoolName.upcase.strip
    end

    def any_remaining_benefit
      yesno(%w[moreThanSixMonths sixMonthsOrLess].include?(@applicant.benefitLeft))
    end
  end
end
