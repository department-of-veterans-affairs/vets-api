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

    # Add form-specific helper methods here based on your JSON structure
    # Examples:
    # 
    # def school_name
    #   @applicant['schoolDetails']['schoolName']
    # end
    #
    # def program_type
    #   @applicant['programInformation']['programType']
    # end
    #
    # def benefit_type
    #   @applicant['benefitType']
    # end
  end
end
