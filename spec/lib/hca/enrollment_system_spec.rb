# frozen_string_literal: true
require 'spec_helper'
require 'hca/enrollment_system'

describe HCA::EnrollmentSystem do
  TEST_ADDRESS = {
    'street' => '123 NW 8th St',
    'street2' =>  '',
    'street3' =>  '',
    'city' => 'Dulles',
    'country' => 'USA',
    'postalCode' => '13AA',
    'provinceCode' => 'ProvinceName',
    'state' => 'VA',
    'zipcode' => '20101-0101'
  }.freeze

  TEST_CHILD = {
    "childFullName": {
      "first": 'FirstChildA',
      "middle": 'MiddleChildA',
      "last": 'LastChildA',
      "suffix": 'Jr.'
    },
    "childRelation": 'Stepson',
    "childSocialSecurityNumber": '111-22-9876',
    "childBecameDependent": '1992-04-07',
    "childDateOfBirth": '1982-05-05',
    "childDisabledBefore18": true,
    "childAttendedSchoolLastYear": true,
    "childEducationExpenses": 45.2,
    "childCohabitedLastYear": true,
    "childReceivedSupportLastYear": false,
    "grossIncome": 991.9,
    "netIncome": 981.2,
    "otherIncome": 91.9
  }.deep_stringify_keys

  TEST_SPOUSE = {
    'spouseAddress' => TEST_ADDRESS,
    'spousePhone' => '1112221234',
    'spouseDateOfBirth' => '1980-04-06',
    'spouseFullName' => {
      'first' => 'FirstSpouse',
      'middle' => 'MiddleSpouse',
      'last' => 'LastSpouse',
      'suffix' => 'Sr.'
    },
    'dateOfMarriage' => '1983-05-10',
    'spouseSocialSecurityNumber' => '111-22-1234'
  }.freeze

  TEST_SPOUSE_WITH_DISCLOSURE = TEST_SPOUSE.merge(
    'maritalStatus' => 'Married',
    'understandsFinancialDisclosure' => true
  ).freeze

  SPOUSE_FINANCIALS = {
    'maritalStatus' => 'Married',
    'understandsFinancialDisclosure' => true,
    'spouseGrossIncome' => 64.1,
    'spouseNetIncome' => 35.1,
    'spouseOtherIncome' => 12.3,
    'cohabitedLastYear' => true,
    'provideSupportLastYear' => false
  }.merge(TEST_SPOUSE).freeze

  CONVERTED_SPOUSE_FINANCIALS = {
    'spouseFinancials' => {
      'incomes' => {
        'income' => [
          { 'amount' => 64.1, 'type' => 7 },
          { 'amount' => 35.1, 'type' => 13 },
          { 'amount' => 12.3, 'type' => 10 }
        ]
      },
      'spouse' =>
      { 'dob' => '04/06/1980',
        'givenName' => 'FIRSTSPOUSE',
        'middleName' => 'MIDDLESPOUSE',
        'familyName' => 'LASTSPOUSE',
        'suffix' => 'SR.',
        'relationship' => 2,
        'startDate' => '05/10/1983',
        'ssns' => { 'ssn' => { 'ssnText' => '111221234' } },
        'address' =>
        { 'city' => 'Dulles',
          'country' => 'USA',
          'line1' => '123 NW 8th St',
          'state' => 'VA',
          'zipCode' => '20101',
          'zipPlus4' => '0101',
          'phoneNumber' => '1112221234' } },
      'contributedToSpousalSupport' => false,
      'livedWithPatient' => true
    }
  }.freeze

  CONVERTED_CHILD_ASSOCIATION = {
    'contactType' => 11,
    'relationship' => 'Stepson',
    'givenName' => 'FIRSTCHILDA',
    'middleName' => 'MIDDLECHILDA',
    'familyName' => 'LASTCHILDA',
    'suffix' => 'JR.'
  }.freeze

  CONVERTED_SPOUSE_ASSOCIATION = {
    'address' => {
      'city' => 'Dulles',
      'country' => 'USA',
      'line1' => '123 NW 8th St',
      'state' => 'VA',
      'zipCode' => '20101',
      'zipPlus4' => '0101'
    },
    'contactType' => 10,
    'relationship' => 'SPOUSE',
    'givenName' => 'FIRSTSPOUSE',
    'middleName' => 'MIDDLESPOUSE',
    'familyName' => 'LASTSPOUSE',
    'suffix' => 'SR.'
  }.freeze

  CHILD_DEPENDENT_FINANCIALS = {
    'incomes' => {
      'income' => [
        { 'amount' => 991.9, 'type' => 7 },
        { 'amount' => 981.2, 'type' => 13 },
        { 'amount' => 91.9, 'type' => 10 }
      ]
    },
    'expenses' => { 'expense' => [{ 'amount' => 45.2, 'expenseType' => '16' }] },
    'dependentInfo' => {
      'dob' => '05/05/1982',
      'givenName' => 'FIRSTCHILDA',
      'middleName' => 'MIDDLECHILDA',
      'familyName' => 'LASTCHILDA',
      'suffix' => 'JR.',
      'relationship' => 5,
      'ssns' => { 'ssn' => { 'ssnText' => '111229876' } },
      'startDate' => '04/07/1992'
    },
    'livedWithPatient' => true,
    'incapableOfSelfSupport' => true,
    'attendedSchool' => true,
    'contributedToSupport' => false
  }.freeze

  let(:test_address) { TEST_ADDRESS.dup }

  %w(veteran result).each do |file|
    let("test_#{file}") do
      JSON.parse(
        File.read(
          Rails.root.join('spec', 'fixtures', 'hca', "#{file}.json")
        )
      )
    end
  end

  test_method(
    described_class,
    'financial_flag?',
    [
      [
        { 'understandsFinancialDisclosure' => true },
        true
      ],
      [
        { 'discloseFinancialInformation' => true },
        true
      ],
      [
        {
          'discloseFinancialInformation' => false,
          'understandsFinancialDisclosure' => false
        },
        false
      ]
    ]
  )

  test_method(
    described_class,
    'format_zipcode',
    [
      [
        '12345',
        { 'zipCode' => '12345', 'zipPlus4' => nil }
      ],
      [
        '12345-1234',
        { 'zipCode' => '12345', 'zipPlus4' => '1234' }
      ],
      [
        '12345-123',
        { 'zipCode' => '12345', 'zipPlus4' => nil }
      ]
    ]
  )

  describe '#format_address' do
    it 'should format the address correctly' do
      expect(described_class.format_address(test_address)).to eq(
        'city' => 'Dulles',
        'country' => 'USA',
        'line1' => '123 NW 8th St',
        'state' => 'VA',
        'zipCode' => '20101',
        'zipPlus4' => '0101'
      )
    end

    context 'with a non american address' do
      before do
        test_address['country'] = 'COM'
      end

      it 'should format the address correctly' do
        expect(described_class.format_address(test_address)).to eq(
          'city' => 'Dulles',
          'country' => 'COM',
          'line1' => '123 NW 8th St',
          'provinceCode' => 'VA',
          'postalCode' => '20101-0101'
        )
      end
    end
  end

  test_method(
    described_class,
    'marital_status_to_sds_code',
    [
      %w(Married M),
      ['Never Married', 'S'],
      %w(Separated A),
      %w(Widowed W),
      %w(Divorced D),
      %w(foo U)
    ]
  )

  test_method(
    described_class,
    'spanish_hispanic_to_sds_code',
    [
      [true, '2135-2'],
      [false, '2186-5'],
      ['foo', '0000-0']
    ]
  )

  test_method(
    described_class,
    'phone_number_from_veteran',
    [
      [
        {
          'homePhone' => '1234'
        },
        {
          'phone' => [
            {
              'phoneNumber' => '1234',
              'type' => '1'
            }
          ]
        }
      ],
      [
        {
          'mobilePhone' => '1234'
        },
        {
          'phone' => [
            {
              'phoneNumber' => '1234',
              'type' => '4'
            }
          ]
        }
      ],
      [
        {
          'homePhone' => '1234',
          'mobilePhone' => '4'
        },
        {
          'phone' => [
            {
              'phoneNumber' => '1234',
              'type' => '1'
            },
            {
              'phoneNumber' => '4',
              'type' => '4'
            }
          ]
        }
      ],
      [
        {},
        nil
      ]
    ]
  )

  test_method(
    described_class,
    'email_from_veteran',
    [
      [
        { 'email' => 'f@f.com' },
        [
          {
            'email' => {
              'address' => 'f@f.com',
              'type' => '1'
            }
          }
        ]
      ],
      [
        {},
        nil
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_races',
    [
      [
        {
          'isAmericanIndianOrAlaskanNative' => true
        },
        {
          'race' => ['1002-5']
        }
      ],
      [
        {
          'isAmericanIndianOrAlaskanNative' => true,
          'isWhite' => true
        },
        {
          'race' => ['1002-5', '2106-3']
        }
      ],
      [
        {},
        nil
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_spouse_info',
    [
      [
        TEST_SPOUSE,
        {
          'dob' => '04/06/1980',
          'givenName' => 'FIRSTSPOUSE',
          'middleName' => 'MIDDLESPOUSE',
          'familyName' => 'LASTSPOUSE',
          'suffix' => 'SR.',
          'relationship' => 2,
          'startDate' => '05/10/1983',
          'ssns' => { 'ssn' => { 'ssnText' => '111221234' } },
          'address' => {
            'city' => 'Dulles',
            'country' => 'USA',
            'line1' => '123 NW 8th St',
            'state' => 'VA',
            'zipCode' => '20101',
            'zipPlus4' => '0101',
            'phoneNumber' => '1112221234'
          }
        }
      ]
    ]
  )

  test_method(
    described_class,
    'resource_to_income_collection',
    [
      [
        {
          'grossIncome' => 991.9,
          'netIncome' => 981.2,
          'otherIncome' => 91.9
        },
        {
          'income' => [
            {
              'amount' => 991.9,
              'type' => 7
            },
            {
              'amount' => 981.2,
              'type' => 13
            },
            {
              'amount' => 91.9,
              'type' => 10
            }
          ]
        }
      ]
    ]
  )

  test_method(
    described_class,
    'resource_to_expense_collection',
    [
      [
        { 'childEducationExpenses' => 1198.11 },
        {
          'expense' => [{
            'amount' => 1198.11,
            'expenseType' => '16'
          }]
        }
      ]
    ]
  )

  test_method(
    described_class,
    'child_relationship_to_sds_code',
    [
      ['Daughter', 4],
      ['Son', 3],
      ['Stepson', 5],
      ['Stepdaughter', 6],
      ['', nil]
    ]
  )

  test_method(
    described_class,
    'child_to_dependent_info',
    [
      [
        TEST_CHILD,
        {
          'dob' => '05/05/1982',
          'givenName' => 'FIRSTCHILDA',
          'middleName' => 'MIDDLECHILDA',
          'familyName' => 'LASTCHILDA',
          'suffix' => 'JR.',
          'relationship' => 5,
          'ssns' => { 'ssn' => { 'ssnText' => '111229876' } },
          'startDate' => '04/07/1992'
        }
      ]
    ]
  )

  test_method(
    described_class,
    'child_to_dependent_financials_info',
    [
      [
        TEST_CHILD,
        CHILD_DEPENDENT_FINANCIALS
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_dependent_financials_collection',
    [
      [
        { 'children' => [TEST_CHILD] },
        {
          'dependentFinancials' => [CHILD_DEPENDENT_FINANCIALS]
        }
      ],
      [{ 'children' => [] }, nil]
    ]
  )

  test_method(
    described_class,
    'veteran_to_spouse_financials',
    [
      [{ 'maritalStatus' => 'Single' }, nil],
      [{ 'maritalStatus' => 'Married' }, nil],
      [
        SPOUSE_FINANCIALS,
        CONVERTED_SPOUSE_FINANCIALS
      ]
    ]
  )

  test_method(
    described_class,
    'provider_to_insurance_info',
    [
      [
        {
          "insuranceName": 'MyInsruance',
          "insurancePolicyHolderName": 'FirstName ZZTEST',
          "insurancePolicyNumber": 'P1234',
          "insuranceGroupCode": 'G1234'
        }.stringify_keys,
        {
          'companyName' => 'MyInsruance',
          'policyHolderName' => 'FirstName ZZTEST',
          'policyNumber' => 'P1234',
          'groupNumber' => 'G1234',
          'insuranceMappingTypeName' => 'PI'
        }
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_person_info',
    [
      [
        {
          "veteranFullName": {
            "first": 'FirstName',
            "middle": 'MiddleName',
            "last": 'ZZTEST',
            "suffix": 'Jr.'
          },
          "mothersMaidenName": 'Maiden',
          "veteranSocialSecurityNumber": '111-11-1234',
          "gender": 'F',
          "cityOfBirth": 'Springfield',
          "stateOfBirth": 'AK',
          "veteranDateOfBirth": '1923-01-02'
        }.deep_stringify_keys,
        {
          'firstName' => 'FIRSTNAME',
          'middleName' => 'MIDDLENAME',
          'lastName' => 'ZZTEST',
          'suffix' => 'JR.',
          'gender' => 'F',
          'dob' => '01/02/1923',
          'mothersMaidenName' => 'Maiden',
          'placeOfBirthCity' => 'Springfield',
          'placeOfBirthState' => 'AK',
          'ssnText' => '111111234'
        }
      ]
    ]
  )

  test_method(
    described_class,
    'service_branch_to_sds_code',
    [
      ['army', 1],
      ['air force', 2],
      ['navy', 3],
      ['marine corps', 4],
      ['coast guard', 5],
      ['merchant seaman', 7],
      ['noaa', 10],
      ['usphs', 9],
      ['f.commonwealth', 11],
      ['f.guerilla', 12],
      ['f.scouts new', 13],
      ['f.scouts old', 14],
      ['foo', 6]
    ]
  )

  test_method(
    described_class,
    'discharge_type_to_sds_code',
    [
      ['honorable', 1],
      ['general', 3],
      ['bad-conduct', 6],
      ['dishonorable', 2],
      ['undesirable', 5],
      ['foo', 4]
    ]
  )

  test_method(
    described_class,
    'veteran_to_military_service_info',
    [
      [
        {
          'disabledInLineOfDuty' => true,
          'dischargeType' => 'general',
          'lastEntryDate' => '1980-03-07',
          'lastDischargeDate' => '1984-07-08',
          'lastServiceBranch' => 'merchant seaman',
          'vaMedicalFacility' => '689A4'
        },
        {
          "dischargeDueToDisability": true,
          "militaryServiceSiteRecords": {
            "militaryServiceSiteRecord": {
              "militaryServiceEpisodes": {
                "militaryServiceEpisode": {
                  "dischargeType": 3,
                  "startDate": '03/07/1980',
                  "endDate": '07/08/1984',
                  "serviceBranch": 7
                }
              },
              "site": '689A4'
            }
          }
        }.deep_stringify_keys
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_insurance_collection',
    [
      [
        {
          "providers": [
            {
              "insuranceName": 'MyInsruance',
              "insurancePolicyHolderName": 'FirstName ZZTEST',
              "insurancePolicyNumber": 'P1234',
              "insuranceGroupCode": 'G1234'
            }
          ],
          "isEnrolledMedicarePartA": true,
          "medicarePartAEffectiveDate": '1999-10-16'
        }.deep_stringify_keys,
        {
          "insurance": [
            {
              "companyName": 'MyInsruance',
              "policyHolderName": 'FirstName ZZTEST',
              "policyNumber": 'P1234',
              "groupNumber": 'G1234',
              "insuranceMappingTypeName": 'PI'
            },
            {
              "companyName": 'Medicare',
              "enrolledInPartA": true,
              "insuranceMappingTypeName": 'MDCR',
              "partAEffectiveDate": '10/16/1999'
            }
          ]
        }.deep_stringify_keys
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_enrollment_determination_info',
    [
      [
        {
          "isMedicaidEligible": true,
          "exposedToRadiation": true,
          "radiumTreatments": true,
          "isVaServiceConnected": false,
          "swAsiaCombat": true,
          "vietnamService": true,
          "campLejeune": true
        }.deep_stringify_keys,
        {
          "eligibleForMedicaid": true,
          "noseThroatRadiumInfo": {
            "receivingTreatment": true
          },
          "serviceConnectionAward": {
            "serviceConnectedIndicator": false
          },
          "specialFactors": {
            "agentOrangeInd": true,
            "envContaminantsInd": true,
            "campLejeuneInd": true,
            "radiationExposureInd": true
          }
        }.deep_stringify_keys
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_financials_info',
    [
      [
        {
          "deductibleMedicalExpenses": 33.3,
          "deductibleFuneralExpenses": 44.44,
          "deductibleEducationExpenses": 77.77,
          "veteranGrossIncome": 123.33,
          "veteranNetIncome": 90.11,
          "veteranOtherIncome": 10.1,
          'children' => [TEST_CHILD]
        }.merge(SPOUSE_FINANCIALS).deep_stringify_keys,
        {
          'incomeTest' => { 'discloseFinancialInformation' => true },
          'financialStatement' => {
            'expenses' => {
              'expense' => [
                { 'amount' => 77.77, 'expenseType' => '3' },
                { 'amount' => 44.44, 'expenseType' => '19' },
                { 'amount' => 33.3, 'expenseType' => '18' }
              ]
            },
            'incomes' => {
              'income' => [
                { 'amount' => 123.33, 'type' => 7 },
                { 'amount' => 90.11, 'type' => 13 },
                { 'amount' => 10.1, 'type' => 10 }
              ]
            },
            'spouseFinancialsList' => CONVERTED_SPOUSE_FINANCIALS,
            'marriedLastCalendarYear' => true,
            'dependentFinancialsList' => {
              'dependentFinancials' => [CHILD_DEPENDENT_FINANCIALS]
            },
            'numberOfDependentChildren' => 1
          }
        }
      ]
    ]
  )

  test_method(
    described_class,
    'relationship_to_contact_type',
    [
      ['Primary Next of Kin', 1],
      ['Other Next of Kin', 2],
      ['Emergency Contact', 3],
      ['Other emergency contact', 4],
      ['Designee', 5],
      ['Beneficiary Representative', 6],
      ['Power of Attorney', 7],
      ['Guardian VA', 8],
      ['Guardian Civil', 9],
      ['Spouse', 10],
      ['Dependent', 11],
      ['foo', nil]
    ]
  )

  test_method(
    described_class,
    'child_to_association',
    [
      [
        TEST_CHILD,
        CONVERTED_CHILD_ASSOCIATION
      ]
    ]
  )

  test_method(
    described_class,
    'spouse_to_association',
    [
      [
        TEST_SPOUSE_WITH_DISCLOSURE,
        CONVERTED_SPOUSE_ASSOCIATION
      ],
      [
        {
          'maritalStatus' => 'Single',
          'understandsFinancialDisclosure' => true
        },
        nil
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_association_collection',
    [
      [
        { 'children' => [TEST_CHILD] },
        {
          'association' => [
            CONVERTED_CHILD_ASSOCIATION
          ]
        }
      ],
      [
        {
          'children' => [TEST_CHILD]
        }.merge(TEST_SPOUSE_WITH_DISCLOSURE),
        {
          'association' => [
            CONVERTED_CHILD_ASSOCIATION,
            CONVERTED_SPOUSE_ASSOCIATION
          ]
        }
      ],
      [
        { 'children' => [] },
        nil
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_demographics_info',
    [
      [
        {
          "veteranAddress": {
            "street": '123 NW 5th St',
            "street2": '',
            "street3": '',
            "city": 'Ontario',
            "country": 'CAN',
            "state": 'ON',
            "provinceCode": 'ProvinceName',
            "zipcode": '21231',
            "postalCode": '13AA'
          },
          wantsInitialVaContact: true,
          "email": 'foo@example.com',
          "homePhone": '1231241234',
          "isSpanishHispanicLatino": true,
          "isWhite": true,
          "maritalStatus": 'Married',
          "vaMedicalFacility": '689A4',
          "isEssentialAcaCoverage": true
        }.deep_stringify_keys,
        {
          'appointmentRequestResponse' => true,
          'contactInfo' =>
          { 'addresses' =>
            { 'address' =>
              { 'city' => 'Ontario',
                'country' => 'CAN',
                'line1' => '123 NW 5th St',
                'provinceCode' => 'ON',
                'postalCode' => '21231',
                'addressTypeCode' => 'P' } },
            'emails' => [{ 'email' => { 'address' => 'foo@example.com', 'type' => '1' } }],
            'phones' => {
              'phone' => [{ 'phoneNumber' => '1231241234', 'type' => '1' }]
            } },
          'ethnicity' => '2135-2',
          'maritalStatus' => 'M',
          'preferredFacility' => '689A4',
          'races' => { 'race' => ['2106-3'] },
          'acaIndicator' => true
        }
      ]
    ]
  )

  describe '#veteran_to_summary' do
    let(:veteran) do
      {
        'isFormerPow' => true,
        'purpleHeartRecipient' => false
      }
    end

    it 'should return the right hash' do
      %w(
        association_collection
        demographics_info
        enrollment_determination_info
        financials_info
        insurance_collection
        military_service_info
        person_info
      ).each do |type|
        expect(described_class).to receive("veteran_to_#{type}")
          .once.with(veteran).and_return(type)
      end

      expect(described_class.veteran_to_summary(veteran)).to eq(
        'associations' => 'association_collection',
        'demographics' => 'demographics_info',
        'enrollmentDeterminationInfo' => 'enrollment_determination_info',
        'financialsInfo' => 'financials_info',
        'insuranceList' => 'insurance_collection',
        'militaryServiceInfo' => 'military_service_info',
        'prisonerOfWarInfo' => { 'powIndicator' => true },
        'purpleHeart' => { 'indicator' => false },
        'personInfo' => 'person_info'
      )
    end
  end

  test_method(
    described_class,
    'convert_hash_values',
    [
      [
        {
          a: 1,
          b: { c: true },
          d: 'true',
          e: [
            { a: 1.1 }, { b: { c: false } }, false
          ]
        },
        {
          a: '1',
          b: { c: 'true' },
          d: 'true',
          e: [
            { a: '1.1' },
            { b: { c: 'false' } },
            'false'
          ]
        }
      ]
    ]
  )

  describe '#veteran_to_save_submit_form' do
    it 'should return the right result' do
      Timecop.freeze(Date.new(2015, 10, 21)) do
        expect(described_class.veteran_to_save_submit_form(test_veteran)).to eq(test_result)
      end
    end
  end

  describe 'hca json schema' do
    it 'test application should pass json schema' do
      expect(test_veteran.to_json).to match_vets_schema('healthcare_application')
    end
  end
end
