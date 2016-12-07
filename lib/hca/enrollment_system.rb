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

    SERVICE_BRANCH_CODES = {
      'army' => 1,
      'air force' => 2,
      'navy' => 3,
      'marine corps' => 4,
      'coast guard' => 5,
      'merchant seaman' => 7,
      'noaa' => 10,
      'usphs' => 9,
      'f.commonwealth' => 11,
      'f.guerilla' => 12,
      'f.scouts new' => 13,
      'f.scouts old' => 14
    }.freeze

    DISCHARGE_CODES = {
      'honorable' => 1,
      'general' => 3,
      'bad-conduct' => 6,
      'dishonorable' => 2,
      'undesirable' => 5
    }.freeze

    RELATIONSHIP_CODES = {
      'Primary Next of Kin' => 1,
      'Other Next of Kin' => 2,
      'Emergency Contact' => 3,
      'Other emergency contact' => 4,
      'Designee' => 5,
      'Beneficiary Representative' => 6,
      'Power of Attorney' => 7,
      'Guardian VA' => 8,
      'Guardian Civil' => 9,
      'Spouse' => 10,
      'Dependent' => 11
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

      { 'phone' => phone }
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
        'relationship' => 2,
        'startDate' => Validations.date_of_birth(veteran['dateOfMarriage']),
        'ssns' => {
          'ssn' => ssn_to_ssntext(veteran['spouseSocialSecurityNumber'])
        },
        'address' => address
      }.merge(convert_full_name_alt(veteran['spouseFullName']))
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
        'relationship' => child_relationship_to_sds_code(child['childRelation']),
        'ssns' => {
          'ssn' => ssn_to_ssntext(child['childSocialSecurityNumber'])
        },
        'startDate' => Validations.date_of_birth(child['childBecameDependent'])
      }.merge(convert_full_name_alt(child['childFullName']))
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

    def spouse?(veteran)
      %w(Married Separated).include?(veteran['maritalStatus'])
    end

    def veteran_to_spouse_financials(veteran)
      return if !spouse?(veteran) || !financial_flag?(veteran)

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

    def convert_full_name_alt(full_name)
      {
        'givenName' => Validations.validate_name(data: full_name['first']),
        'middleName' => Validations.validate_name(data: full_name['middle']),
        'familyName' => Validations.validate_name(data: full_name['last']),
        'suffix' => Validations.validate_name(data: full_name['suffix'])
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

    def service_branch_to_sds_code(service_branch)
      SERVICE_BRANCH_CODES[service_branch] || 6
    end

    def discharge_type_to_sds_code(discharge_type)
      DISCHARGE_CODES[discharge_type] || 4
    end

    def veteran_to_military_service_info(veteran)
      {
        'dischargeDueToDisability' => veteran['disabledInLineOfDuty'],
        'militaryServiceSiteRecords' => {
          'militaryServiceSiteRecord' => {
            'militaryServiceEpisodes' => {
              'militaryServiceEpisode' => {
                'dischargeType' => discharge_type_to_sds_code(veteran['dischargeType']),
                'startDate' => Validations.date_of_birth(veteran['lastEntryDate']),
                'endDate' => Validations.date_of_birth(veteran['lastDischargeDate']),
                'serviceBranch' => service_branch_to_sds_code(veteran['lastServiceBranch'])
              }
            },
            'site' => veteran['vaMedicalFacility']
          }
        }
      }
    end

    def veteran_to_insurance_collection(veteran)
      insurance_collection = veteran['providers'].map do |provider|
        provider_to_insurance_info(provider)
      end

      if veteran['isEnrolledMedicarePartA']
        insurance_collection << {
          'companyName' => 'Medicare',
          'enrolledInPartA' => veteran['isEnrolledMedicarePartA'],
          'insuranceMappingTypeName' => 'MDCR',
          'partAEffectiveDate' => Validations.date_of_birth(veteran['medicarePartAEffectiveDate'])
        }
      end

      return if insurance_collection.blank?

      {
        'insurance' => insurance_collection
      }
    end

    def veteran_to_enrollment_determination_info(veteran)
      {
        'eligibleForMedicaid' => veteran['isMedicaidEligible'],
        'noseThroatRadiumInfo' => {
          'receivingTreatment' => veteran['radiumTreatments']
        },
        'serviceConnectionAward' => {
          'serviceConnectedIndicator' => veteran['isVaServiceConnected']
        },
        'specialFactors' => {
          'agentOrangeInd' => veteran['vietnamService'],
          'envContaminantsInd' => veteran['swAsiaCombat'],
          'campLejeuneInd' => veteran['campLejeune'],
          'radiationExposureInd' => veteran['exposedToRadiation']
        }
      }
    end

    def veteran_to_financials_info(veteran)
      return unless financial_flag?(veteran)

      {
        'incomeTest' => { 'discloseFinancialInformation' => true },
        'financialStatement' => {
          'expenses' => resource_to_expense_collection(
            'educationExpense' => veteran['deductibleEducationExpenses'],
            'funeralExpense' => veteran['deductibleFuneralExpenses'],
            'medicalExpense' => veteran['deductibleMedicalExpenses']
          ),
          'incomes' => resource_to_income_collection(
            'grossIncome' => veteran['veteranGrossIncome'],
            'netIncome' => veteran['veteranNetIncome'],
            'otherIncome' => veteran['veteranOtherIncome']
          ),
          'spouseFinancialsList' => veteran_to_spouse_financials(veteran),
          'marriedLastCalendarYear' => veteran['maritalStatus'] == 'Married',
          'dependentFinancialsList' => veteran_to_dependent_financials_collection(veteran),
          'numberOfDependentChildren' => veteran['children'].size
        }
      }
    end

    def relationship_to_contact_type(relationship)
      RELATIONSHIP_CODES[relationship]
    end

    def child_to_association(child)
      {
        'contactType' => relationship_to_contact_type('Dependent'),
        'relationship' => child['childRelation']
      }.merge(convert_full_name_alt(child['childFullName']))
    end

    def spouse_to_association(veteran)
      if spouse?(veteran) && financial_flag?(veteran)
        {
          'address' => format_address(veteran['spouseAddress']),
          'contactType' => relationship_to_contact_type('Spouse'),
          'relationship' => 'SPOUSE'
        }.merge(convert_full_name_alt(veteran['spouseFullName']))
      end
    end

    def veteran_to_association_collection(veteran)
      associations = []
      children = veteran['children'].map do |child|
        child_to_association(child)
      end.compact
      spouse = spouse_to_association(veteran)

      associations += children
      associations << spouse if spouse.present?

      return if associations.blank?

      { 'association' => associations }
    end

    def veteran_to_demographics_info(veteran)
      address = format_address(veteran['veteranAddress'])
      address['addressTypeCode'] = 'P'

      {
        'appointmentRequestResponse' => veteran['wantsInitialVaContact'],
        'contactInfo' => {
          'addresses' => {
            'address' => address
          },
          'emails' => email_from_veteran(veteran),
          'phones' => phone_number_from_veteran(veteran)
        },
        'ethnicity' => spanish_hispanic_to_sds_code(veteran['isSpanishHispanicLatino']),
        'maritalStatus' => marital_status_to_sds_code(veteran['maritalStatus']),
        'preferredFacility' => veteran['vaMedicalFacility'],
        'races' => veteran_to_races(veteran),
        'acaIndicator' => veteran['isEssentialAcaCoverage']
      }
    end

    def veteran_to_summary(veteran)
      {
        'associations' => veteran_to_association_collection(veteran),
        'demographics' => veteran_to_demographics_info(veteran),
        'enrollmentDeterminationInfo' => veteran_to_enrollment_determination_info(veteran),
        'financialsInfo' => veteran_to_financials_info(veteran),
        'insuranceList' => veteran_to_insurance_collection(veteran),
        'militaryServiceInfo' => veteran_to_military_service_info(veteran),
        'prisonerOfWarInfo' => {
          'powIndicator' => veteran['isFormerPow']
        },
        'purpleHeart' => {
          'indicator' => veteran['purpleHeartRecipient']
        },
        'personInfo' => veteran_to_person_info(veteran)
      }
    end

    def convert_value(value)
      if value.is_a?(Hash)
        convert_hash_values(value)
      elsif value.is_a?(Array)
        value.map do |item|
          convert_value(item)
        end
      elsif value.in?([true, false]) || value.is_a?(Numeric)
        value.to_s
      else
        value
      end
    end

    def convert_hash_values(hash)
      hash.each do |k, v|
        hash[k] = convert_value(v)
      end
    end

    def veteran_to_save_submit_form(veteran)
      return {} if veteran.blank?

      request = FORM_TEMPLATE.dup
      request['form']['summary'] = veteran_to_summary(veteran)
      request['form']['applications'] = {
        'applicationInfo' => {
          'appDate' => Time.zone.now.utc.strftime('%Y-%m-%d'),
          'appMethod' => '1'
        }
      }

      convert_hash_values(request)
      request
    end
  end
  # rubocop:enable ModuleLength
end
