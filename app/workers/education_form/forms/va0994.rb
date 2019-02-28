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
      'computerProgramming': 'Computer programming',
      'dataProcessing': 'Data processing',
      'computerSoftware': 'Computer software',
      'informationSciences': 'Information sciences',
      'mediaApplication': 'Media application'
    }.freeze

    SALARY_TEXT = {
      'lessThanTwenty': '<$20,000',
      'twentyToThirtyFive': '$20,000-$35,000',
      'thirtyFiveToFifty': '$35,000-$50,000',
      'fiftyToSeventyFive': '$50,000-$75,000',
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
      if @applicant.bankAccount&.routingNumber.present?
        @applicant.bankAccount.routingNumber
      else
        value_or_na(@applicant.prefillBankAccount&.bankRoutingNumber)
      end
    end

    def bank_account_number
      if @applicant.bankAccount&.accountNumber.present?
        @applicant.bankAccount.accountNumber
      else
        value_or_na(@applicant.prefillBankAccount&.bankAccountNumber)
      end
    end

    def bank_account_type
      if @applicant.bankAccount&.accountType.present?
        @applicant.bankAccount.accountType
      else
        value_or_na(@applicant.prefillBankAccount&.bankAccountType)
      end
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
      areas.join("\n")
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

    def full_address_with_street3(address, indent: false)
      return '' if address.nil?
      seperator = indent ? "\n        " : "\n"
      [
        address.street,
        address.street2,
        address.street3,
        [address.city, address.state, address.postalCode].compact.join(', '),
        address.country
      ].compact.join(seperator).upcase
    end
  end
end
