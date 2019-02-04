# frozen_string_literal: true

module EducationForm::Forms
  class VA0994 < Base
    def header_form_type
      'V0994'
    end

    def benefit_type
      'VetTec'
    end

    HIGH_TECH_AREA_NAMES = {
      'computerProgramming': 'Computer Programming',
      'dataProcessing': 'Data Processing',
      'computerSoftware': 'Computer Software',
      'informationSciences': 'Information Sciences',
      'mediaApplication': 'Media Application'
    }.freeze

    SALARY_TEXT = {
      'lessThanTwenty': '<$20,000',
      'twentyToThirtyFive': '$20,001-$35,000',
      'thirtyFiveToFifty': '$35,001-$50,000',
      'fiftyToSeventyFive': '$50,001-$75,000',
      'moreThanSeventyFive': '>$75,000'
    }.freeze

    EDUCATION_TEXT = {
      'high_school_diploma_or_GED': 'High school diploma or GED',
      'some_college': 'Some college',
      'associates_degree': 'Associate’s degree',
      'bachelors_degree': 'Bachelor’s degree',
      'masters_degree': 'Master’s degree',
      'doctoral_degree': 'Doctoral degree',
      'other': 'Other'
    }.freeze

    COURSE_TYPE_TEXT = {
      'inPerson': 'In Person',
      'online': 'Online',
      'both': 'Both'
    }.freeze

    def applicant_name
      @applicant.applicantFullName
    end

    def applicant_ssn
      @applicant.applicantSocialSecurityNumber
    end

    def bank_routing_number
      return 'N/A' if @applicant.bankAccount.blank?
      value_or_na(@applicant.bankAccount.routingNumber)
    end

    def bank_account_number
      return 'N/A' if @applicant.bankAccount.blank?
      value_or_na(@applicant.bankAccount.accountNumber)
    end

    def bank_account_type
      return 'N/A' if @applicant.bankAccount.blank?
      value_or_na(@applicant.bankAccount.accountType)
    end

    def location
      return 'N/A' if @applicant.vetTecProgramLocations.blank?
      "#{@applicant.vetTecProgramLocations.city}, #{@applicant.vetTecProgramLocations.state}"
    end

    def high_tech_area_names
      return 'N/A' if @applicant.highTechnologyEmploymentTypes.blank?

      areas = []
      @applicant.highTechnologyEmploymentTypes.each do |area|
        areas.push(HIGH_TECH_AREA_NAMES[area.to_sym])
      end
      areas.join(', ')
    end

    def education_level_name
      return 'N/A' if @applicant.highestLevelofEducation.blank?
      return @applicant.otherEducation if @applicant.highestLevelofEducation == 'other'
      EDUCATION_TEXT[@applicant.highestLevelofEducation.to_sym]
    end

    def course_type_name(course_type)
      return 'N/A' if course_type.blank?
      COURSE_TYPE_TEXT[course_type.to_sym]
    end

    def salary_text
      return 'N/A' if @applicant.currentSalary.blank?
      SALARY_TEXT[@applicant.currentSalary.to_sym]
    end
  end
end
