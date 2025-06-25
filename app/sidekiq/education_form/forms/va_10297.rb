# frozen_string_literal: true

module EducationForm::Forms
  class VA10297 < Base
    def header_form_type
      'V10297'
    end

    def benefit_type
      'VetTec'
    end

    HIGH_TECH_AREA_NAMES = {
      computerProgramming: 'Computer programming',
      computerSoftware: 'Computer software',
      mediaApplication: 'Media application',
      dataProcessing: 'Data processing',
      informationSciences: 'Information sciences',
      somethingElse: 'Other'
    }.freeze

    SALARY_TEXT = {
      lessThanTwenty: '<$20,000',
      twentyToThirtyFive: '$20,000-$35,000',
      thirtyFiveToFifty: '$35,000-$50,000',
      fiftyToSeventyFive: '$50,000-$75,000',
      moreThanSeventyFive: '>$75,000'
    }.freeze

    EDUCATION_TEXT = {
      HS: 'High school',
      AD: 'Associate’s degree',
      BD: 'Bachelor’s degree',
      MD: 'Master’s degree',
      DD: 'Doctoral degree',
      NA: 'Other'
    }.freeze

    COURSE_TYPE_TEXT = {
      inPerson: 'In Person',
      online: 'Online',
      both: 'Both'
    }.freeze

    def applicant_name
      @applicant.applicantFullName
    end

    def applicant_ssn
      @applicant.applicantFileNumber
    end

    def new_bank_info?
      @applicant.bankAccount&.routingNumber.present? ||
        @applicant.bankAccount&.accountNumber.present? ||
        @applicant.bankAccount&.accountType.present?
    end

    def bank_routing_number
      if @applicant.bankAccount&.routingNumber.present?
        @applicant.bankAccount.routingNumber
      elsif !new_bank_info?
        @applicant.prefillBankAccount&.bankRoutingNumber
      end
    end

    def bank_account_number
      if @applicant.bankAccount&.accountNumber.present?
        @applicant.bankAccount.accountNumber
      elsif !new_bank_info?
        @applicant.prefillBankAccount&.bankAccountNumber
      end
    end

    def bank_account_type
      if @applicant.bankAccount&.accountType.present?
        @applicant.bankAccount.accountType
      elsif !new_bank_info?
        @applicant.prefillBankAccount&.bankAccountType
      end
    end

    def education_level_name
      return '' if @applicant.highestLevelofEducation.blank?

      EDUCATION_TEXT[@applicant.highestLevelofEducation.to_sym]
    end

    def course_type_name(course_type)
      return '' if course_type.blank?

      COURSE_TYPE_TEXT[course_type.to_sym]
    end

    def high_tech_area_name
      return '' if @applicant.technologyAreaOfFocus.blank?

      HIGH_TECH_AREA_NAMES[@applicant.technologyAreaOfFocus.to_sym]
    end

    def salary_text
      return 'N/A' unless @applicant.isEmployed && @applicant.isInTechnologyIndustry
      return '' if @applicant.currentSalary.blank?

      SALARY_TEXT[@applicant.currentSalary.to_sym]
    end

    def get_program_block(program)
      program.providerAddress
      [
        ["\n  Provider name: ", program.providerName].join,
        "\n  Location:",
        ["\n    City: ", program.providerAddress.city].join,
        ["\n    State: ", program.providerAddress.state].join
      ].join
    end

    def program_text
      return '' if @applicant.hitechVetsPrograms&.programs.blank?

      program_blocks = []
      @applicant.hitechVetsPrograms.programs.each do |program|
        program_blocks.push(get_program_block(program))
      end
      program_blocks.push(["\n  Planned start date: ", @applicant.hitechVetsPrograms.plannedStartDate].join)

      program_blocks.join("\n")
    end

    def full_address_with_street2(address, indent: false)
      return '' if address.nil?

      seperator = indent ? "\n        " : "\n"
      [
        address.street,
        address.street2,
        [address.city, address.state, address.postalCode].compact.join(', '),
        address.country
      ].compact.join(seperator).upcase
    end
  end
end
