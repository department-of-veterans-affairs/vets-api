# frozen_string_literal: true

module EducationForm::Forms
  class VA10203 < Base
    def header_form_type
      'V10203'
    end

    def form_benefit
      @applicant.benefit&.titleize
    end

    def school_name
      @applicant.schoolName.upcase.strip
    end

    def any_remaining_benefit
      yesno(%w[moreThanSixMonths sixMonthsOrLess].include?(benefit_left))
    end

    def receive_text_message
      return false if @applicant.receiveTexts.nil?

      @applicant.receiveTexts
    end

    def benefit_left
      @applicant.benefitLeft
    end

    def pursuing_teaching_cert
      @applicant.isPursuingTeachingCert
    end
  end
end
