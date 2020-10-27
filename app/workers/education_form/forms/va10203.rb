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
      yesno(%w[moreThanSixMonths sixMonthsOrLess].include?(@applicant.benefitLeft))
    end

    def receive_text_message
      return nil unless Flipper.enabled?(:stem_text_message_question)

      return false if @applicant.receiveTexts.nil?

      @applicant.receiveTexts
    end
  end
end
