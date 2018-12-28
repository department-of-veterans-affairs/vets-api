# frozen_string_literal: true

module EducationForm::Forms
  class VA0994 < Base
    def header_form_type
      'VE0994'
    end

    PROGRAM_NAMES = {
      'program1': 'Program 1',
      'program2': 'Program 2',
      'program3': 'Program 3',
      'program4': 'Program 4',
      'program5': 'Program 5'
    }.freeze

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

    def applicant_name
      @applicant.applicantFullName
    end

    def applicant_ssn
      @applicant.applicantSocialSecurityNumber
    end

    def location
      "#{@applicant.vetTecProgramLocations.city}, #{@applicant.vetTecProgramLocations.state}"
    end

    def selected_programs
      programs = []

      @applicant.vetTecProgram.each do |program|
        programs.push(PROGRAM_NAMES[program.to_sym])
      end

      programs.join(', ')
    end

    def high_tech_area_name
      HIGH_TECH_AREA_NAMES[@applicant.highTechnologyEmploymentType.to_sym]
    end

    def salary_text
      SALARY_TEXT[applicant.currentSalary.to_sym]
    end
  end
end
