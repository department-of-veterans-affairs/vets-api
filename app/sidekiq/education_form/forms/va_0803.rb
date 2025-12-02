# frozen_string_literal: true

module EducationForm::Forms
  class VA0803 < Base
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
      super(app)
    end
  end
end
