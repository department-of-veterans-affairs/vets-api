require 'hca/validations'

# frozen_string_literal: true
module HCA
  # rubocop:disable ModuleLength
  module EnrollmentSystem
    module_function

    RACE_CODES = {
      'isAmericanIndianOrAlaskanNative' => '1002-5',
      'isAsian' => '2028-9',
      'isBlackOrAfricanAmerican' => '2054-5',
      'isNativeHawaiianOrOtherPacificIslander' => '2076-8',
      'isWhite' => '2106-3'
    }.freeze

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

      [
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
      RACE_CODES.each do |race_key, code|
        races << code if veteran[race_key]
      end

      return if races.size.zero?

      { 'race' => races }
    end

    def veteran_to_spouse_info(veteran)
      address = format_address(veteran['spouseAddress'])
      address['phoneNumber'] = veteran['spousePhone']

      {
        'dob' => Validations.date_of_birth(veteran['spouseDateOfBirth']),
        'givenName' => Validations.validate_name(data: veteran['spouseFullName']['first']),
        'middleName' => Validations.validate_name(data: veteran['spouseFullName']['middle']),
        'familyName' => Validations.validate_name(data: veteran['spouseFullName']['last']),
        'suffix' => Validations.validate_name(data: veteran['spouseFullName']['suffix']),
        'relationship' => 2,
        'startDate' => Validations.date_of_birth(veteran['dateOfMarriage']),
        'ssns' => {
          'ssn' => ssn_to_ssntext(veteran['spouseSocialSecurityNumber'])
        },
        'address' => address
      }
    end

    def resource_to_income_collection(resource)
      income_collection = []

      [
        ['grossIncome', 7],
        ['netIncome', 13],
        ['otherIncome', 10]
      ].each do |income_type|
        income = resource[income_type[0]]

        if income.present?
          income_collection << {
            'amount' => income,
            'type' => income_type[1]
          }
        end
      end

      return if income_collection.size.zero?

      {
        'income' => income_collection
      }
    end

    def resource_to_expense_collection(resource)
      expense_collection = []

      [
        %w(educationExpense 3),
        %w(childEducationExpenses 16),
        %w(funeralExpense 19),
        %w(medicalExpense 18)
      ].each do |expense_type|
        expense = resource[expense_type[0]]

        if expense.present?
          expense_collection << {
            'amount' => expense,
            'expenseType' => expense_type[1]
          }
        end
      end

      return if expense_collection.size.zero?

      {
        'expense' => expense_collection
      }
    end

    def child_relationship_to_sds_code(child_relationship)
      case child_relationship
      when 'Daughter'
        4
      when 'Son'
        3
      when 'Stepson'
        5
      when 'Stepdaughter'
        6
      end
    end

    def child_to_dependent_info(child)
      {
        'dob' => Validations.date_of_birth(child['childDateOfBirth']),
        'givenName' => Validations.validate_name(data: child['childFullName']['first']),
        'middleName' => Validations.validate_name(data: child['childFullName']['middle']),
        'familyName' => Validations.validate_name(data: child['childFullName']['last']),
        'suffix' => Validations.validate_name(data: child['childFullName']['suffix']),
        'relationship' => child_relationship_to_sds_code(child['childRelation']),
        'ssns' => {
          'ssn' => ssn_to_ssntext(child['childSocialSecurityNumber'])
        },
        'startDate' => Validations.date_of_birth(child['childBecameDependent'])
      }
    end

    def child_to_dependent_financials_info(child)
      {
        'incomes' => resource_to_income_collection(child),
        'expenses' => resource_to_expense_collection(child),
        'dependentInfo' => child_to_dependent_info(child),
        'livedWithPatient' => child['childCohabitedLastYear'],
        'incapableOfSelfSupport' => child['childDisabledBefore18'],
        'attendedSchool' => child['childAttendedSchoolLastYear'],
        'contributedToSupport' => child['childReceivedSupportLastYear']
      }
    end

    def veteran_to_dependent_financials_collection(veteran)
      children = veteran['children']

      if children.present?
        {
          'dependentFinancials' => children.map do |child|
            child_to_dependent_financials_info(child)
          end
        }
      end
    end

    def veteran_to_spouse_financials(veteran)
      if !%w(Married Separated).include?(veteran['maritalStatus']) || !financial_flag?(veteran)
        return
      end

      spouse_income = resource_to_income_collection(
        'grossIncome' => veteran['spouseGrossIncome'],
        'netIncome' => veteran['spouseNetIncome'],
        'otherIncome' => veteran['spouseOtherIncome']
      )

      cohabited_last_year = veteran['cohabitedLastYear']
      cohabited_last_year = false if cohabited_last_year.blank?

      {
        'spouseFinancials' => {
          'incomes' => spouse_income,
          'spouse' => veteran_to_spouse_info(veteran),
          'contributedToSpousalSupport' => veteran['provideSupportLastYear'],
          'livedWithPatient' => cohabited_last_year
        }
      }
    end

    def provider_to_insurance_info(provider)
      {
        'companyName' => provider['insuranceName'],
        'policyHolderName' => provider['insurancePolicyHolderName'],
        'policyNumber' => provider['insurancePolicyNumber'],
        'groupNumber' => provider['insuranceGroupCode'],
        'insuranceMappingTypeName' => 'PI'
      }
    end

    def ssn_to_ssntext(ssn)
      {
        'ssnText' => Validations.validate_ssn(ssn)
      }
    end

    def convert_full_name(full_name)
      {
        'firstName' => Validations.validate_name(
          data: full_name['first'],
          count: 30
        ),
        'middleName' => Validations.validate_name(
          data: full_name['middle'],
          count: 30,
          nullable: true
        ),
        'lastName' => Validations.validate_name(
          data: full_name['last'],
          count: 30
        ),
        'suffix' => Validations.validate_name(
          data: full_name['suffix']
        )
      }
    end

    def veteran_to_person_info(veteran)
      convert_full_name(veteran['veteranFullName']).merge({
        'gender' => veteran['gender'],
        'dob' => Validations.date_of_birth(veteran['veteranDateOfBirth']),
        'mothersMaidenName' => Validations.validate_string(
          data: veteran['mothersMaidenName'],
          count: 35,
          nullable: true
        ),
        'placeOfBirthCity' => Validations.validate_string(
          data: veteran['cityOfBirth'],
          count: 20,
          nullable: true
        ),
        'placeOfBirthState' => veteran['stateOfBirth']
      }.merge(ssn_to_ssntext(veteran['veteranSocialSecurityNumber'])))
    end

    def transform(data)
    end
  end
  # rubocop:enable ModuleLength
end
