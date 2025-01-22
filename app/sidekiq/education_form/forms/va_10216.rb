# frozen_string_literal: true

module EducationForm::Forms
  class VA10216 < Base
    # rubocop:disable Lint/MissingSuper
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
    end
    # rubocop:enable Lint/MissingSuper

    def institution_name
      @applicant['institutionDetails']['institutionName']
    end

    def facility_code
      @applicant['institutionDetails']['facilityCode']
    end

    def term_start_date
      @applicant['institutionDetails']['termStartDate']
    end

    def beneficiary_students
      @applicant['studentRatioCalcChapter']['beneficiaryStudent']
    end

    def total_students
      @applicant['studentRatioCalcChapter']['numOfStudent']
    end

    def va_beneficiary_percentage
      @applicant['studentRatioCalcChapter']['VaBeneficiaryStudentsPercentage']
    end

    def calculation_date
      @applicant['studentRatioCalcChapter']['dateOfCalculation']
    end

    def header_form_type
      'V10216'
    end
  end
end
