# frozen_string_literal: true

module EducationForm::Forms
  class VA8794 < Base
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
      super(education_benefits_claim)
    end

    def designating_official_name
      @applicant['designatingOfficial']['fullName']
    end

    def designating_official_title
      @applicant['designatingOfficial']['title']
    end

    def designating_official_email
      @applicant['designatingOfficial']['emailAddress']
    end

    def institution_name
      @applicant['institutionDetails']['institutionName']
    end

    def facility_code
      @applicant['institutionDetails']['facilityCode']
    end

    def va_facility_code?
      @applicant['institutionDetails']['hasVaFacilityCode']
    end

    def primary_official_name
      @applicant['primaryOfficialDetails']['fullName']
    end

    def primary_official_title
      @applicant['primaryOfficialDetails']['title']
    end

    def primary_official_email
      @applicant['primaryOfficialDetails']['emailAddress']
    end

    def training_completion_date
      @applicant['primaryOfficialTraining']['trainingCompletionDate']
    end

    def training_exempt
      @applicant['primaryOfficialTraining']['trainingExempt']
    end

    def va_education_benefits?
      @applicant['primaryOfficialBenefitStatus']['hasVaEducationBenefits']
    end

    def additional_certifying_officials
      @applicant['additionalCertifyingOfficials'] || []
    end

    def read_only_certifying_official?
      @applicant['hasReadOnlyCertifyingOfficial']
    end

    def read_only_certifying_officials
      @applicant['readOnlyCertifyingOfficial'] || []
    end

    def remarks
      @applicant['remarks']
    end

    def statement_of_truth_signature
      @applicant['statementOfTruthSignature']
    end

    def date_signed
      @applicant['dateSigned']
    end

    def header_form_type
      'V8794'
    end
  end
end
