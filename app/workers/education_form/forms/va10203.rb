# frozen_string_literal: true

module EducationForm::Forms
  class VA10203 < Base
    def initialize(app)
      @education_stem_automated_decision = app.education_stem_automated_decision
      super(app)
    end

    def header_form_type
      @education_stem_automated_decision&.automated_decision_state == 'denied' ? '10203DNY' : 'V10203'
    end

    def form_identifier
      @education_stem_automated_decision&.automated_decision_state == 'denied' ? 'VA Form 22-10203DNY' : 'VA Form 22-10203'
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
      return false if @applicant.receiveTexts.nil?

      @applicant.receiveTexts
    end
  end
end
