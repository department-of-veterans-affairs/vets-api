# frozen_string_literal: true

module EducationForm::Forms
  class VA10215 < Base
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
      super(app)
    end

    def institution_name
      @applicant['institutionDetails']['institutionName']
    end

    def facility_code
      @applicant['institutionDetails']['facilityCode']
    end

    def term_start_date
      @applicant['institutionDetails']['termStartDate']
    end

    def calculation_date
      @applicant['institutionDetails']['dateOfCalculations']
    end

    def programs
      @applicant['programs']
    end

    def header_form_type
      'V10215'
    end
  end
end
