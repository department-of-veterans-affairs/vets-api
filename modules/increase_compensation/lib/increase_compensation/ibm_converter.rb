# frozen_string_literal: true

module IncreaseCompensation
  module IbmConverter
    # IBM Key Map
    MAPPINGS = {
      'VETERAN_FIRST_NAME' => ->(data) { data.dig('veteranFullName', 'first') || '' },
      'VETERAN_INITIAL' => ->(data) { extract_first_char(data.dig('veteranFullName', 'middleinitial')) || '' },
      'VETERAN_LAST_NAME' => ->(data) { data.dig('veteranFullName', 'last') || '' },
      'VETERAN_NAME' => ->(data) { full_name(data['veteranFullName']) || '' },
      'VETERAN_SSN' => ->(data) { data['veteranSocialSecurityNumber'] || '' },
      'VA_FILE_NUMBER' => ->(data) { data['vaFileNumber'] || '' },
      'VETERAN_DOB' => ->(data) { format_date(data['dateOfBirth']) || '' },
      'VETERAN_ADDRESS_LINE1' => ->(data) { data.dig('veteranAddress', 'street') || '' },
      'VETERAN_ADDRESS_LINE2' => ->(data) { data.dig('veteranAddress', 'street2') || '' },
      'VETERAN_ADDRESS_CITY' => ->(data) { data.dig('veteranAddress', 'city') || '' },
      'VETERAN_ADDRESS_STATE' => ->(data) { data.dig('veteranAddress', 'state') || '' },
      'VETERAN_ADDRESS_COUNTRY' => ->(data) { data.dig('veteranAddress', 'country') || '' },
      'VETERAN_ADDRESS_ZIP5' => ->(data) { data.dig('veteranAddress', 'postalCode') || '' },
      'SERVICE_CONNECTED_DISABILITY' => ->(data) { data['listOfDisabilities'] || '' },
      'VETERAN_SSN_1' => ->(data) { data['veteranSocialSecurityNumber'] || '' },

      # Employers Section
      # Employer From From #1
      'EMPLOYER_NAME_ADDRESS_1' => ->(data) { data.dig('previousEmployers', 0, 'nameAndAddress') || '' },
      'WORK_TYPE_1' => ->(data) { data.dig('previousEmployers', 0, 'typeOfWork') || '' },
      'DATE_OF_EMPLOYMENT_FROM_1' => lambda { |data|
        format_date(data.dig('previousEmployers', 0, 'datesOfEmployment', 'from'))
      },
      'DATE_OF_EMPLOYMENT_TO_1' => lambda { |data|
        format_date(data.dig('previousEmployers', 0, 'datesOfEmployment', 'to'))
      },

      # Employer From From #2
      'EMPLOYER_NAME_ADDRESS_2' => ->(data) { data.dig('previousEmployers', 1, 'nameAndAddress') || '' },
      'WORK_TYPE_2' => ->(data) { data.dig('previousEmployers', 1, 'typeOfWork') || '' },
      'DATE_OF_EMPLOYMENT_FROM_2' => lambda { |data|
        format_date(data.dig('previousEmployers', 1, 'datesOfEmployment', 'from'))
      },
      'DATE_OF_EMPLOYMENT_TO_2' => lambda { |data|
        format_date(data.dig('previousEmployers', 1, 'datesOfEmployment', 'to'))
      },

      # Employer From From #3
      'EMPLOYER_NAME_ADDRESS_3' => ->(data) { data.dig('previousEmployers', 2, 'nameAndAddress') || '' },
      'WORK_TYPE_3' => ->(data) { data.dig('previousEmployers', 2, 'typeOfWork') || '' },
      'DATE_OF_EMPLOYMENT_FROM_3' => lambda { |data|
        format_date(data.dig('previousEmployers', 2, 'datesOfEmployment', 'from'))
      },
      'DATE_OF_EMPLOYMENT_TO_3' => lambda { |data|
        format_date(data.dig('previousEmployers', 2, 'datesOfEmployment', 'to'))
      },

      # Employer From From #4
      'EMPLOYER_NAME_ADDRESS_4' => ->(data) { data.dig('previousEmployers', 3, 'nameAndAddress') || '' },
      'WORK_TYPE_4' => ->(data) { data.dig('previousEmployers', 3, 'typeOfWork') || '' },
      'DATE_OF_EMPLOYMENT_FROM_4' => lambda { |data|
        format_date(data.dig('previousEmployers', 3, 'datesOfEmployment', 'from'))
      },
      'DATE_OF_EMPLOYMENT_TO_4' => lambda { |data|
        format_date(data.dig('previousEmployers', 3, 'datesOfEmployment', 'to'))
      },

      # Employer From From #5
      'EMPLOYER_NAME_ADDRESS_5' => ->(data) { data.dig('previousEmployers', 4, 'nameAndAddress') || '' },
      'WORK_TYPE_5' => ->(data) { data.dig('previousEmployers', 4, 'typeOfWork') || '' },
      'DATE_OF_EMPLOYMENT_FROM_5' => lambda { |data|
        format_date(data.dig('previousEmployers', 4, 'datesOfEmployment', 'from'))
      },
      'DATE_OF_EMPLOYMENT_TO_5' => lambda { |data|
        format_date(data.dig('previousEmployers', 4, 'datesOfEmployment', 'to'))
      },
      # End Employers

      'VETERAN_SSN_2' => ->(data) { data['veteranSocialSecurityNumber'] || '' },
      'VETERAN_SSN_3' => ->(data) { data['veteranSocialSecurityNumber'] || '' },
      'CLAIMANT_SIGNATURE' => ->(data) { data['signature'] || data['statementOfTruthSignature'] || '' },
      'WITNESS_1_SIGNATURE' => ->(data) { data.dig('witnessSignature1', 'signature') || '' },
      'WITNESS_1_ADDRESS' => ->(data) { data.dig('witnessSignature1', 'address') || '' },
      'WITNESS_2_SIGNATURE' => ->(data) { data.dig('witnessSignature2', 'signature') || '' },
      'WITNESS_2_ADDRESS' => ->(data) { data.dig('witnessSignature2', 'address') || '' },
      'VETERAN_BENEFICIARY_REMARKS' => ->(data) { data['remarks'] || '' }
    }.freeze

    ##
    # Converts claim.parsed_form to a hash using IBM keys and formats.
    #
    # @param form_data [Hash] claim.parsed_form
    #
    # @return [Hash] ruby object with IBM keys
    #
    def self.convert(form_data)
      MAPPINGS.transform_values do |proc|
        proc.call(form_data)
      end
    end

    # Helper Methods

    ## Return the 1st character for VETERAN_INITIAL
    def self.extract_first_char(str)
      str&.[](0) || ''
    end

    ## Changes date format to MM/DD/YYYY
    #
    def self.format_date(str)
      return '' if str.blank? || str.nil?

      date_array = str.split('-')
      # date_array[1] = month, last = day, first = year
      "#{date_array[1]}/#{date_array.last}/#{date_array.first}"
    end

    ## Returns full name as one string
    #
    def self.full_name(name_obj)
      return '' if name_obj.blank? || name_obj.nil?

      [
        name_obj['first'],
        name_obj['middleinitial'],
        name_obj['last']
      ].compact.join(' ')
    end
  end
end
