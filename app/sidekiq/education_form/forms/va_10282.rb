# frozen_string_literal: true

module EducationForm::Forms
  class VA10282 < Base
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
    end

    def name
      "#{first_name} #{last_name}"
    end

    def first_name
      @applicant.veteranFullName.first
    end

    def last_name
      @applicant.veteranFullName.last
    end

    def military_affiliation
      @applicant.veteranDesc
    end

    def phone_number
      @applicant&.contactInfo&.phone || 'Not provided'
    end

    def email_address
      @applicant.contactInfo.email
    end

    def country
      @applicant.country
    end

    def state
      @applicant.state
    end

    def race_ethnicity
      @applicant.originRace
    end

    def gender
      @applicant.raceAndGender
    end

    def education_level
      @applicant.highestLevelOfEducation.level
    end

    def employment_status
      @applicant.currentlyEmployed
    end

    def salary
      @applicant.currentAnnualSalary
    end

    def technology_industry
      return nil unless @applicant.isWorkingInTechIndustry

      @applicant.techIndustryFocusArea
    end

    def header_form_type
      'V10282'
    end
  end
end
