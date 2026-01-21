# frozen_string_literal: true

module EducationForm::Forms
  class VA0976 < Base
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
      super(education_benefits_claim)
    end

    def header_form_type
      'V0976'
    end
  end
end
