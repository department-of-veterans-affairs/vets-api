# frozen_string_literal: true

module EducationForm::Forms
  class VA10282 < Base
    SALARY_TYPES = {
      moreThanSeventyFive: 'More than $75,000',
      thirtyFiveToFifty: '$35,000 - $50,000',
      fiftyToSeventyFive: '$50,000 - $75,000',
      twentyToThirtyFive: '$20,000 - $35,000',
      lessThanTwenty: 'Less than $20,000'
    }.freeze

    TECH_AREAS = {
      CP: 'Computer Programming',
      DP: 'Data Processing',
      CS: 'Cyber Security',
      IS: 'Information Security',
      MA: 'Mobile Applications',
      NA: 'Not Applicable'
    }.freeze

    GENDER_TYPES = {
      'M' => 'Male',
      'W' => 'Female',
      'TW' => 'Transgender Woman',
      'TM' => 'Transgender Man',
      'NB' => 'Non-Binary',
      '0' => 'Other',
      'NA' => 'Prefer Not to Answer'
    }.freeze

    EDUCATION_LEVELS = {
      'HS' => 'High School',
      'AD' => 'Associate Degree',
      'BD' => "Bachelor's Degree",
      'MD' => "Master's Degree",
      'DD' => 'Doctorate Degree',
      'NA' => 'Prefer Not to Answer'
    }.freeze

    MILITARY_TYPES = {
      'veteran' => 'Veteran',
      'veteransSpouse' => "Veteran's Spouse",
      'veteransChild' => "Veteran's Child",
      'veteransCaregiver' => "Veteran's Caregiver",
      'activeduty' => 'Active Duty',
      'nationalGuard' => 'National Guard',
      'reservist' => 'Reservist',
      'individualReadyReserve' => 'Individual Ready Reserve'
    }.freeze

    ETHNICITY_TYPES = {
      'HL' => 'Hispanic or Latino',
      'NHL' => 'Not Hispanic or Latino',
      'NA' => 'Prefer Not to Answer'
    }.freeze

    # rubocop:disable Lint/MissingSuper
    def initialize(education_benefits_claim)
      @education_benefits_claim = education_benefits_claim
      @applicant = education_benefits_claim.parsed_form
    end
    # rubocop:enable Lint/MissingSuper

    def name
      "#{first_name} #{last_name}"
    end

    def first_name
      @applicant['veteranFullName']['first']
    end

    def last_name
      @applicant['veteranFullName']['last']
    end

    def military_affiliation
      MILITARY_TYPES[@applicant['veteranDesc']] || 'Not specified'
    end

    def phone_number
      @applicant.dig('contactInfo', 'mobilePhone') ||
        @applicant.dig('contactInfo', 'homePhone') ||
        'Not provided'
    end

    def email_address
      @applicant['contactInfo']['email']
    end

    def country
      @applicant['country']
    end

    def state
      @applicant['state']
    end

    def race_ethnicity
      races = []
      origin_race = @applicant['originRace']

      races << 'American Indian or Alaska Native' if origin_race['isAmericanIndianOrAlaskanNative']
      races << 'Asian' if origin_race['isAsian']
      races << 'Black or African American' if origin_race['isBlackOrAfricanAmerican']
      races << 'Native Hawaiian or Other Pacific Islander' if origin_race['isNativeHawaiianOrOtherPacificIslander']
      races << 'White' if origin_race['isWhite']
      races << 'Prefer Not to Answer' if origin_race['noAnswer']

      return 'Not specified' if races.empty?

      races.join(', ')
    end

    def gender
      GENDER_TYPES[@applicant['gender']] || 'Not specified'
    end

    def education_level
      EDUCATION_LEVELS[@applicant['highestLevelOfEducation']['level']] || 'Not specified'
    end

    def employment_status
      @applicant['currentlyEmployed'] ? 'Yes' : 'No'
    end

    def salary
      SALARY_TYPES[@applicant['currentAnnualSalary']&.to_sym] || 'Not specified'
    end

    def technology_industry
      return 'No' unless @applicant['isWorkingInTechIndustry']

      TECH_AREAS[@applicant['techIndustryFocusArea']&.to_sym] || 'Not specified'
    end

    def header_form_type
      'V10282'
    end
  end
end
