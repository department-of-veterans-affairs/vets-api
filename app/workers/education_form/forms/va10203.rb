# frozen_string_literal: true

module EducationForm::Forms
  class VA10203 < Base

    def header_form_type
      'V10203'
    end

    def form_benefit
      @applicant.benefit&.titleize
    end

    def any_remaining_benefit
      yesno(['moreThanSixMonths', 'sixMonthsOrLess'].include?(@applicant.benefitLeft))
    end
  end
end
