# frozen_string_literal: true

module EducationForm::Forms
  class VA1919 < Base
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
      super(education_benefits_claim)
    end

    def institution_name
      @applicant['institutionDetails']['institutionName']
    end

    def facility_code
      @applicant['institutionDetails']['facilityCode']
    end

    def certifying_official_name
      official = @applicant['certifyingOfficial']
      return '' unless official

      "#{official['first']} #{official['last']}"
    end

    def certifying_official_role
      role = @applicant['certifyingOfficial']['role']
      return '' unless role

      role['level'] == 'other' ? role['other'] : role['level']
    end

    def proprietary_conflicts_count
      conflicts = @applicant['proprietaryProfitConflicts']
      return 0 unless conflicts

      [conflicts.length, 2].min # Max 2 as per requirement
    end

    def proprietary_conflicts
      conflicts = @applicant['proprietaryProfitConflicts']
      return [] unless conflicts

      conflicts.first(2) # Take only first 2
    end

    def all_proprietary_conflicts_count
      conflicts = @applicant['allProprietaryProfitConflicts']
      return 0 unless conflicts

      [conflicts.length, 2].min # Max 2 as per requirement
    end

    def all_proprietary_conflicts
      conflicts = @applicant['allProprietaryProfitConflicts']
      return [] unless conflicts

      conflicts.first(2) # Take only first 2
    end

    def header_form_type
      'V1919'
    end
  end
end
