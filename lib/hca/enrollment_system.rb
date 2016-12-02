# frozen_string_literal: true
module HCA
  module EnrollmentSystem
    module_function

    FORM_TEMPLATE = {
      'form' => {
        'formIdentifier' => {
          'type' => '100',
          'value' => '1010EZ',
          'version' => 1_986_360_435
        }
      },
      'identity' => {
        'authenticationLevel' => {
          'type' => '100',
          'value' => 'anonymous'
        }
      }
    }.freeze

    def financial_flag?(veteran)
      veteran['understandsFinancialDisclosure'] || veteran['discloseFinancialInformation']
    end

    def format_address(address)
      formatted = address.slice('city', 'country')
      formatted['line1'] = address['street']

      (2..3).each do |i|
        street = address["street#{i}"]
        next if street.blank?
        formatted["line#{i}"] = street
      end

      if address['country'] == 'USA'
        formatted['state'] = address['state']
        formatted.merge!(format_zipcode(address['zipcode']))
      else
        formatted['provinceCode'] = address['state'] || address['provinceCode']
        formatted['postalCode'] = address['zipcode'] || address['postalCode']
      end

      formatted
    end

    def format_zipcode(zipcode)
      numeric_zip = zipcode.gsub(/\D/, '')
      zip_plus_4 = numeric_zip[5..8]
      zip_plus_4 = nil if !zip_plus_4.nil? && zip_plus_4.size != 4

      {
        'zipCode' => numeric_zip[0..4],
        'zipPlus4' => zip_plus_4
      }
    end

    def marital_status_to_sds_code(marital_status)
      case marital_status
      when 'Married'
        'M'
      when 'Never Married'
        'S'
      when 'Separated'
        'A'
      when 'Widowed'
        'W'
      when 'Divorced'
        'D'
      else
        'U'
      end
    end

    def spanish_hispanic_to_sds_code(is_spanish_hispanic_latino)
      case is_spanish_hispanic_latino
      when true
        '2135-2'
      when false
        '2186-5'
      else
        '0000-0'
      end
    end

    def phone_number_from_veteran(veteran)
      return if veteran['homePhone'].blank? && veteran['mobilePhone'].blank?

      phone = []
      %w(homePhone mobilePhone).each do |type|
        number = veteran[type]

        phone << {
          'phoneNumber' => number,
          'type' => (type == 'homePhone' ? '1' : '4')
        } if number.present?
      end

      phone
    end

    def email_from_veteran(veteran)
      email = veteran['email']
      return if email.blank?

      return [
        {
          'email' => {
            'address' => email,
            'type' => '1'
          }
        }
      ]
    end

    def veteran_to_races(veteran)
      races = []
      races << '1002-5' if veteran['isAmericanIndianOrAlaskanNative']
      races << '2028-9' if veteran['isAsian']
      races << '2054-5' if veteran['isBlackOrAfricanAmerican']
      races << '2076-8' if veteran['isNativeHawaiianOrOtherPacificIslander']
      races << '2106-3' if veteran['isWhite']

      return if races.size == 0

      { 'race' => races }
    end

    def veteran_to_spouse_info(veteran)
      # address = format_address(veteran['spouseAddress'])
      # address['phoneNumber'] = veteran['spousePhone']

      # {
      #   'dob' => 
      # }

      # const address = formatAddress(veteran.spouseAddress);
      # address.phoneNumber = veteran.spousePhone;

      # return {
      #   dob: validations.dateOfBirth(veteran.spouseDateOfBirth),
      #   givenName: validations.validateName(veteran.spouseFullName.first),
      #   middleName: validations.validateName(veteran.spouseFullName.middle),
      #   familyName: validations.validateName(veteran.spouseFullName.last),
      #   suffix: validations.validateName(veteran.spouseFullName.suffix),
      #   relationship: 2,
      #   startDate: validations.dateOfBirth(veteran.dateOfMarriage),
      #   ssns: {
      #     ssn: {
      #       ssnText: validations.validateSsn(veteran.spouseSocialSecurityNumber)
      #     }
      #   },
      #   address
      # };
    end

    def transform(data)
    end
  end
end
