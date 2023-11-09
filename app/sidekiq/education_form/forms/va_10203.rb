# frozen_string_literal: true

module EducationForm::Forms
  class VA10203 < Base
    def initialize(app)
      @stem_automated_decision = app.education_stem_automated_decision
      super(app)
    end

    def denied?
      @stem_automated_decision&.automated_decision_state == 'denied'
    end

    def header_form_type
      denied? ? '10203DNY' : 'V10203'
    end

    def form_identifier
      denied? ? 'VA Form 22-10203DNY' : 'VA Form 22-10203'
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
      @benefit_left ||= @applicant.benefitLeft
    end

    def pursuing_teaching_cert
      @pursuing_teaching_cert ||= @applicant.isPursuingTeachingCert
    end

    def enrolled_stem
      @enrolled_stem ||= @applicant.isEnrolledStem
    end
  end
end
