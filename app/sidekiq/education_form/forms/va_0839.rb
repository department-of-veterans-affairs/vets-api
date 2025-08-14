# frozen_string_literal: true

module EducationForm::Forms
  class VA0839 < Base
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
      super(app)
    end

    def header_form_type
      'V0839'
    end
  end
end
