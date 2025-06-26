# frozen_string_literal: true

module EducationForm::Forms
  class VA1919 < Base
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
      super(app)
    end

    def certifying_official_first_name
      @applicant['certifyingOfficial']['first']
    end

    def certifying_official_last_name
      @applicant['certifyingOfficial']['last']
    end

    def institution_name
      @applicant['institutionDetails']['institutionName']
    end

    def facility_code
      @applicant['institutionDetails']['facilityCode']
    end

    def statement_of_truth_signature
      @applicant['statementOfTruthSignature']
    end

    def date_signed
      @applicant['dateSigned']
    end

    def header_form_type
      'V1919'
    end
  end
end 