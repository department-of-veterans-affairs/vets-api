# frozen_string_literal: true

require 'rails_helper'
require 'hca/enrollment_system'

describe HCA::EnrollmentSystem do
  include SchemaMatchers

  TEST_ADDRESS = {
    'street' => '123 NW 8th St',
    'street2' => '',
    'street3' => '',
    'city' => 'Dulles',
    'country' => 'USA',
    'state' => 'VA',
    'postalCode' => '20101-0101'
  }.freeze

  TEST_CHILD = {
    childFullName: {
      first: 'FirstChildA',
      middle: 'MiddleChildA',
      last: 'LastChildA',
      suffix: 'Jr.'
    },
    childRelation: 'Stepson',
    childSocialSecurityNumber: '111-22-9876',
    childBecameDependent: '1992-04-07',
    childDateOfBirth: '1982-05-05',
    childDisabledBefore18: true,
    childAttendedSchoolLastYear: true,
    childEducationExpenses: 45.2,
    childCohabitedLastYear: true,
    childReceivedSupportLastYear: false,
    grossIncome: 991.9,
    netIncome: 981.2,
    otherIncome: 91.9
  }.deep_stringify_keys

  TEST_CHILD_DEPENDENT = {
    fullName: {
      first: 'FirstChildA',
      middle: 'MiddleChildA',
      last: 'LastChildA',
      suffix: 'Jr.'
    },
    dependentRelation: 'Stepson',
    socialSecurityNumber: '111-22-9876',
    becameDependent: '1992-04-07',
    dateOfBirth: '1982-05-05',
    disabledBefore18: true,
    attendedSchoolLastYear: true,
    dependentEducationExpenses: 45.2,
    cohabitedLastYear: true,
    receivedSupportLastYear: false,
    grossIncome: 991.9,
    netIncome: 981.2,
    otherIncome: 91.9
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

  %w[veteran result].each do |file|
    let("test_#{file}") do
      JSON.parse(
        Rails.root.join('spec', 'fixtures', 'hca', "#{file}.json").read
      )
    end
  end

  test_method(
    described_class,
    'remove_ctrl_chars!',
    [
      [
        {
          a: {
            b: ["sdfsdf\u0010", "sdfsdf\u0010"]
          },
          c: "sdfsdf\u0010"
        },
        { a: { b: %w[sdfsdf sdfsdf] }, c: 'sdfsdf' }
      ]
    ]
  )

  test_method(
    described_class,
    'demographic_no?',
    [
      [
        { 'hasDemographicNoAnswer' => true },
        true
      ],
      [
        { 'hasDemographicNoAnswer' => false },
        false
      ],
      [
        {},
        false
      ]
    ]
  )

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
        [nil],
        {}
      ],
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
    context 'with no zipcode' do
      it 'formats addr correctly' do
        test_address.delete('postalCode')
        expect(described_class.format_address(test_address)).to eq(
          'city' => 'Dulles',
          'country' => 'USA',
          'line1' => '123 NW 8th St',
          'state' => 'VA'
        )
      end
    end

    it 'formats the address correctly' do
      expect(described_class.format_address(test_address)).to eq(
        'city' => 'Dulles',
        'country' => 'USA',
        'line1' => '123 NW 8th St',
        'state' => 'VA',
        'zipCode' => '20101',
        'zipPlus4' => '0101'
      )
    end

    context 'with "Address Type Code" specified' do
      it 'sets the "addressTypeCode" attribute' do
        expect(described_class.format_address(test_address, type: 'P')).to eq(
          'city' => 'Dulles',
          'country' => 'USA',
          'line1' => '123 NW 8th St',
          'state' => 'VA',
          'zipCode' => '20101',
          'zipPlus4' => '0101',
          'addressTypeCode' => 'P'
        )

        expect(described_class.format_address(test_address, type: 'R')).to eq(
          'city' => 'Dulles',
          'country' => 'USA',
          'line1' => '123 NW 8th St',
          'state' => 'VA',
          'zipCode' => '20101',
          'zipPlus4' => '0101',
          'addressTypeCode' => 'R'
        )
      end
    end

    context 'with a non american address' do
      before do
        test_address['country'] = 'COM'
      end

      it 'formats the address correctly' do
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
      %w[Married M],
      ['Never Married', 'S'],
      %w[Separated A],
      %w[Widowed W],
      %w[Divorced D],
      %w[foo U]
    ]
  )

  test_method(
    described_class,
    'spanish_hispanic_to_sds_code',
    [
      [true, '2135-2'],
      [false, '2186-5'],
      %w[foo 0000-0]
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
          'hasDemographicNoAnswer' => true
        },
        {
          'race' => ['0000-0']
        }
      ],
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
          'race' => %w[1002-5 2106-3]
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
    'income_collection_total',
    [
      [
        [nil],
        0
      ],
      [
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
        },
        BigDecimal(2065)
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
        [
          {
            'dependentEducationExpenses' => 999.11,
            'educationExpense' => 200,
            'funeralExpense' => 200
          },
          5000
        ],
        {
          'expense' => [
            { 'amount' => 200, 'expenseType' => '3' },
            { 'amount' => 999.11, 'expenseType' => '16' },
            { 'amount' => 200, 'expenseType' => '19' }
          ]
        }
      ],
      [
        [
          {
            'dependentEducationExpenses' => 999.11,
            'educationExpense' => 200,
            'funeralExpense' => 200
          },
          1000
        ],
        {
          'expense' => [
            { 'amount' => 200, 'expenseType' => '3' },
            { 'amount' => 800.0, 'expenseType' => '16' }
          ]
        }
      ]
    ]
  )

  test_method(
    described_class,
    'dependent_relationship_to_sds_code',
    [
      ['Spouse', 2],
      ['Son', 3],
      ['Daughter', 4],
      ['Stepson', 5],
      ['Stepdaughter', 6],
      ['Father', 17],
      ['Mother', 18],
      ['Other', 99],
      ['', nil]
    ]
  )

  test_method(
    described_class,
    'dependent_info',
    [
      [
        TEST_CHILD_DEPENDENT,
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
    'dependent_financials_info',
    [
      [
        TEST_CHILD_DEPENDENT,
        CHILD_DEPENDENT_FINANCIALS
      ]
    ]
  )

  test_method(
    described_class,
    'veteran_to_dependent_financials_collection',
    [
      [
        { 'dependents' => [TEST_CHILD_DEPENDENT] },
        { 'dependentFinancials' => [CHILD_DEPENDENT_FINANCIALS] }
      ],
      [{ 'dependents' => [] }, nil]
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
          insuranceName: 'MyInsruance',
          insurancePolicyHolderName: 'FirstName ZZTEST',
          insurancePolicyNumber: 'P1234',
          insuranceGroupCode: 'G1234'
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
          veteranFullName: {
            first: 'FirstName',
            middle: 'MiddleName',
            last: 'ZZTEST',
            suffix: 'Jr.'
          },
          mothersMaidenName: 'Maiden',
          veteranSocialSecurityNumber: '111-11-1234',
          gender: 'F',
          cityOfBirth: 'Springfield',
          stateOfBirth: 'AK',
          veteranDateOfBirth: '1923-01-02'
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
    'convert_birth_state',
    [
      %w[
        MN
        MN
      ],
      %w[
        Other
        FG
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
      ['space force', 15],
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
          'vaMedicalFacility' => '608'
        },
        {
          dischargeDueToDisability: true,
          militaryServiceSiteRecords: {
            militaryServiceSiteRecord: {
              site: '608'
            }
          }
        }.deep_stringify_keys
      ],
      [
        {
          'disabledInLineOfDuty' => true,
          'dischargeType' => 'general',
          'lastEntryDate' => '1980-03-07',
          'lastDischargeDate' => '1984-07-08',
          'lastServiceBranch' => 'merchant seaman',
          'vaMedicalFacility' => '608'
        },
        {
          dischargeDueToDisability: true,
          militaryServiceSiteRecords: {
            militaryServiceSiteRecord: {
              militaryServiceEpisodes: {
                militaryServiceEpisode: {
                  dischargeType: 3,
                  startDate: '03/07/1980',
                  endDate: '07/08/1984',
                  serviceBranch: 7
                }
              },
              site: '608'
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
          providers: [
            {
              insuranceName: 'MyInsruance',
              insurancePolicyHolderName: 'FirstName ZZTEST',
              insurancePolicyNumber: 'P1234',
              insuranceGroupCode: 'G1234'
            }
          ],
          isEnrolledMedicarePartA: true,
          medicarePartAEffectiveDate: '1999-10-16'
        }.deep_stringify_keys,
        {
          insurance: [
            {
              companyName: 'MyInsruance',
              policyHolderName: 'FirstName ZZTEST',
              policyNumber: 'P1234',
              groupNumber: 'G1234',
              insuranceMappingTypeName: 'PI'
            },
            {
              companyName: 'Medicare',
              enrolledInPartA: true,
              insuranceMappingTypeName: 'MDCR',
              partAEffectiveDate: '10/16/1999'
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
          isMedicaidEligible: true,
          exposedToRadiation: true,
          radiumTreatments: true,
          isVaServiceConnected: false,
          swAsiaCombat: true,
          vietnamService: true,
          campLejeune: true
        }.deep_stringify_keys,
        {
          eligibleForMedicaid: true,
          noseThroatRadiumInfo: {
            receivingTreatment: true
          },
          serviceConnectionAward: {
            serviceConnectedIndicator: false
          },
          specialFactors: {
            agentOrangeInd: true,
            envContaminantsInd: true,
            campLejeuneInd: true,
            radiationExposureInd: true
          }
        }.deep_stringify_keys
      ],
      [
        {
          hasTeraResponse: true,
          combatOperationService: true
        }.deep_stringify_keys,
        {
          'eligibleForMedicaid' => false,
          'noseThroatRadiumInfo' => {
            'receivingTreatment' => false
          },
          'serviceConnectionAward' => {
            'serviceConnectedIndicator' => false
          },
          'specialFactors' => {
            'agentOrangeInd' => false,
            'envContaminantsInd' => false,
            'campLejeuneInd' => false,
            'radiationExposureInd' => false,
            'supportOperationsInd' => true
          }
        }
      ]
    ]
  )

  describe '#veteran_to_tera' do
    test_method(
      described_class,
      'veteran_to_tera',
      [
        [
          { 'hasTeraResponse' => false },
          {}
        ],
        [
          {
            'hasTeraResponse' => true
          },
          {
            'supportOperationsInd' => false
          }
        ],
        [
          {
            'hasTeraResponse' => true,
            'combatOperationService' => true
          },
          {
            'supportOperationsInd' => true
          }
        ],
        [
          {
            'hasTeraResponse' => true,
            'gulfWarService' => true,
            'gulfWarStartDate' => '1993-16-08',
            'gulfWarEndDate' => '1994-16-07'
          },
          {
            'supportOperationsInd' => false,
            'gulfWarHazard' => {
              'gulfWarHazardInd' => true,
              'fromDate' => '08/16/1993',
              'toDate' => '07/16/1994'
            }
          }
        ]
      ]
    )
  end

  describe '#veteran_to_toxic_exposure' do
    test_method(
      described_class,
      'veteran_to_toxic_exposure',
      [
        [
          {},
          {}
        ],
        [
          {
            'exposureToAirPollutants' => 'true',
            'toxicExposureStartDate' => '1980-16-08',
            'toxicExposureEndDate' => '1989-13-08'
          },
          {
            'toxicExposure' => {
              'exposureCategories' => {
                'exposureCategory' => ['Air Pollutants']
              },
              'otherText' => nil,
              'fromDate' => '08/16/1980',
              'toDate' => '08/13/1989'
            }
          }
        ],
        [
          {
            'exposureToOther' => 'true',
            'otherToxicExposure' => 'other exposure text value here',
            'toxicExposureStartDate' => '1980-16-08',
            'toxicExposureEndDate' => '1989-13-08'
          },
          {
            'toxicExposure' => {
              'exposureCategories' => {
                'exposureCategory' => ['Other']
              },
              'otherText' => 'other exposure text value here',
              'fromDate' => '08/16/1980',
              'toDate' => '08/13/1989'
            }
          }
        ]
      ]
    )
  end

  test_method(
    described_class,
    'veteran_to_financials_info',
    [
      [
        {},
        {
          'incomeTest' => { 'discloseFinancialInformation' => false }
        }
      ],
      [
        {
          deductibleMedicalExpenses: 33.3,
          deductibleFuneralExpenses: 44.44,
          deductibleEducationExpenses: 77.77,
          veteranGrossIncome: 123.33,
          veteranNetIncome: 90.11,
          veteranOtherIncome: 10.1,
          'dependents' => [TEST_CHILD_DEPENDENT]
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
    'dependent_to_association',
    [
      [
        TEST_CHILD_DEPENDENT,
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
        { 'dependents' => [TEST_CHILD_DEPENDENT] },
        {
          'association' => [
            CONVERTED_CHILD_ASSOCIATION
          ]
        }
      ],
      [
        {
          'dependents' => [TEST_CHILD_DEPENDENT]
        }.merge(TEST_SPOUSE_WITH_DISCLOSURE),
        {
          'association' => [
            CONVERTED_CHILD_ASSOCIATION,
            CONVERTED_SPOUSE_ASSOCIATION
          ]
        }
      ],
      [
        { 'dependents' => [] },
        nil
      ]
    ]
  )

  describe '#address_from_veteran' do
    let(:provided_veteran_data) do
      {
        'wantsInitialVaContact' => true,
        'email' => 'foo@example.com',
        'homePhone' => '1231241234',
        'isSpanishHispanicLatino' => true,
        'isWhite' => true,
        'maritalStatus' => 'Married',
        'vaMedicalFacility' => '608',
        'isEssentialAcaCoverage' => false
      }
    end

    context 'with one address' do
      before do
        provided_veteran_data['veteranAddress'] = {
          'street' => '123 NW 5th St',
          'street2' => '',
          'street3' => '',
          'city' => 'Ontario',
          'country' => 'CAN',
          'state' => 'ON',
          'provinceCode' => 'ProvinceName',
          'postalCode' => '21231'
        }
      end

      it 'transforms address and sets "type code"' do
        expect(
          described_class.address_from_veteran(provided_veteran_data)
        ).to eq(
          {
            'address' => {
              'city' => 'Ontario',
              'country' => 'CAN',
              'line1' => '123 NW 5th St',
              'provinceCode' => 'ON',
              'postalCode' => '21231',
              # When only one address present, set as "permanent"
              'addressTypeCode' => 'P'
            }
          }
        )
      end
    end

    context 'with two addresses' do
      before do
        provided_veteran_data['veteranAddress'] = {
          'street' => '123 NW 5th St',
          'street2' => '',
          'street3' => '',
          'city' => 'Ontario',
          'country' => 'CAN',
          'state' => 'ON',
          'provinceCode' => 'ProvinceName',
          'postalCode' => '21231'
        }

        provided_veteran_data['veteranHomeAddress'] = {
          'street' => '567 SW 9th Ave.',
          'street2' => '#102',
          'street3' => '',
          'city' => 'Ontario',
          'country' => 'CAN',
          'state' => 'ON',
          'provinceCode' => 'ProvinceName',
          'postalCode' => '21231'
        }
      end

      it 'transforms address and sets "type code"' do
        expect(
          described_class.address_from_veteran(provided_veteran_data)
        ).to eq(
          'address' => [
            {
              'city' => 'Ontario',
              'country' => 'CAN',
              'line1' => '123 NW 5th St',
              'provinceCode' => 'ON',
              'postalCode' => '21231',
              # Mailing address is marked as "permanent"
              'addressTypeCode' => 'P'
            },
            {
              'city' => 'Ontario',
              'country' => 'CAN',
              'line1' => '567 SW 9th Ave.',
              'line2' => '#102',
              'provinceCode' => 'ON',
              'postalCode' => '21231',
              # Home address is marked as "residential"
              'addressTypeCode' => 'R'
            }
          ]
        )
      end
    end
  end

  test_method(
    described_class,
    'veteran_to_demographics_info',
    [
      [
        {
          veteranAddress: {
            street: '123 NW 5th St',
            street2: '',
            street3: '',
            city: 'Ontario',
            country: 'CAN',
            state: 'ON',
            provinceCode: 'ProvinceName',
            postalCode: '21231'
          },
          wantsInitialVaContact: true,
          email: 'foo@example.com',
          homePhone: '1231241234',
          isSpanishHispanicLatino: true,
          isWhite: true,
          maritalStatus: 'Married',
          vaMedicalFacility: '608',
          isEssentialAcaCoverage: false
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
          'preferredFacility' => '608',
          'races' => { 'race' => ['2106-3'] },
          'acaIndicator' => false
        }
      ],

      [
        {
          veteranAddress: {
            street: '123 NW 5th St',
            street2: '',
            street3: '',
            city: 'Ontario',
            country: 'CAN',
            state: 'ON',
            provinceCode: 'ProvinceName',
            postalCode: '21231'
          },
          veteranHomeAddress: {
            street: '567 SW 9th Ave.',
            street2: '#102',
            street3: '',
            city: 'Ontario',
            country: 'CAN',
            state: 'ON',
            provinceCode: 'ProvinceName',
            postalCode: '21231'
          },
          wantsInitialVaContact: true,
          email: 'foo@example.com',
          homePhone: '1231241234',
          isWhite: true,
          maritalStatus: 'Married',
          vaMedicalFacility: '608',
          isEssentialAcaCoverage: false
        }.deep_stringify_keys,
        {
          'appointmentRequestResponse' => true,
          'contactInfo' => {
            'addresses' => {
              'address' => [
                {
                  'city' => 'Ontario',
                  'country' => 'CAN',
                  'line1' => '123 NW 5th St',
                  'provinceCode' => 'ON',
                  'postalCode' => '21231',
                  'addressTypeCode' => 'P'
                },
                {
                  'city' => 'Ontario',
                  'country' => 'CAN',
                  'line1' => '567 SW 9th Ave.',
                  'line2' => '#102',
                  'provinceCode' => 'ON',
                  'postalCode' => '21231',
                  'addressTypeCode' => 'R'
                }
              ]
            },
            'emails' => [
              { 'email' => { 'address' => 'foo@example.com', 'type' => '1' } }
            ],
            'phones' => {
              'phone' => [{ 'phoneNumber' => '1231241234', 'type' => '1' }]
            }
          },
          'maritalStatus' => 'M',
          'preferredFacility' => '608',
          'races' => { 'race' => ['2106-3'] },
          'acaIndicator' => false
        }
      ],

      [
        {
          veteranAddress: {
            street: '123 NW 5th St',
            street2: '',
            street3: '',
            city: 'Ontario',
            country: 'CAN',
            state: 'ON',
            provinceCode: 'ProvinceName',
            postalCode: '21231'
          },
          veteranHomeAddress: {
            street: '567 SW 9th Ave.',
            street2: '#102',
            street3: '',
            city: 'Ontario',
            country: 'CAN',
            state: 'ON',
            provinceCode: 'ProvinceName',
            postalCode: '21231'
          },
          wantsInitialVaContact: true,
          email: 'foo@example.com',
          homePhone: '1231241234',
          isSpanishHispanicLatino: true,
          isWhite: true,
          maritalStatus: 'Married',
          vaMedicalFacility: '608',
          isEssentialAcaCoverage: false
        }.deep_stringify_keys,
        {
          'appointmentRequestResponse' => true,
          'contactInfo' => {
            'addresses' => {
              'address' => [
                {
                  'city' => 'Ontario',
                  'country' => 'CAN',
                  'line1' => '123 NW 5th St',
                  'provinceCode' => 'ON',
                  'postalCode' => '21231',
                  # Mailing address is marked as "permanent"
                  'addressTypeCode' => 'P'
                },
                {
                  'city' => 'Ontario',
                  'country' => 'CAN',
                  'line1' => '567 SW 9th Ave.',
                  'line2' => '#102',
                  'provinceCode' => 'ON',
                  'postalCode' => '21231',
                  # Home address is marked as "residential"
                  'addressTypeCode' => 'R'
                }
              ]
            },
            'emails' => [
              { 'email' => { 'address' => 'foo@example.com', 'type' => '1' } }
            ],
            'phones' => {
              'phone' => [{ 'phoneNumber' => '1231241234', 'type' => '1' }]
            }
          },
          'ethnicity' => '2135-2',
          'maritalStatus' => 'M',
          'preferredFacility' => '608',
          'races' => { 'race' => ['2106-3'] },
          'acaIndicator' => false
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

    it 'returns the right hash' do
      %w[
        association_collection
        demographics_info
        enrollment_determination_info
        financials_info
        insurance_collection
        military_service_info
        person_info
      ].each do |type|
        expect(described_class).to receive("veteran_to_#{type}")
          .once.with(veteran).and_return(type)
      end

      result = described_class.veteran_to_summary(veteran)
      result.delete(:attributes!)
      expect(result).to eq(
        'eeSummary:associations' => 'association_collection',
        'eeSummary:demographics' => 'demographics_info',
        'eeSummary:enrollmentDeterminationInfo' => 'enrollment_determination_info',
        'eeSummary:financialsInfo' => 'financials_info',
        'eeSummary:insuranceList' => 'insurance_collection',
        'eeSummary:militaryServiceInfo' => 'military_service_info',
        'eeSummary:prisonerOfWarInfo' => { 'eeSummary:powIndicator' => true },
        'eeSummary:purpleHeart' => { 'eeSummary:indicator' => false },
        'eeSummary:personInfo' => 'person_info'
      )
    end
  end

  test_method(
    described_class,
    'copy_spouse_address!',
    [
      [
        {
          'veteranAddress' => {
            'street' => '123 NW 5th St'
          }
        },
        {
          'veteranAddress' => {
            'street' => '123 NW 5th St'
          },
          'spouseAddress' => {
            'street' => '123 NW 5th St'
          }
        }
      ],
      [
        {
          'veteranAddress' => {
            'street' => '123 NW 5th St'
          },
          'spouseAddress' => {
            'street' => 'sdfsdf'
          }
        },
        {
          'veteranAddress' => {
            'street' => '123 NW 5th St'
          },
          'spouseAddress' => {
            'street' => 'sdfsdf'
          }
        }
      ]
    ]
  )

  test_method(
    described_class,
    'convert_hash_values!',
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

  test_method(
    described_class,
    'get_va_format',
    [
      [
        'application/msword',
        'WORD'
      ],
      [
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'WORD'
      ],
      [
        'image/jpeg',
        'JPG'
      ],
      [
        'application/rtf',
        'RTF'
      ],
      [
        'application/pdf',
        'PDF'
      ],
      [
        'application/octet-stream',
        'PDF'
      ],
      [
        'application/unknown-mime',
        'PDF'
      ]
    ]
  )

  describe '#veteran_to_save_submit_form' do
    let(:ez_form) do
      described_class.veteran_to_save_submit_form(test_veteran, nil, '10-10EZ').with_indifferent_access
    end
    let(:ezr_form) do
      described_class.veteran_to_save_submit_form(test_veteran, nil, '10-10EZR').with_indifferent_access
    end

    it 'returns the right result' do
      Timecop.freeze(DateTime.new(2015, 10, 21, 23, 0, 0, '-5')) do
        result = ez_form
        expect(result).to eq(test_result)
        expect(
          result['va:form']['va:applications']['va:applicationInfo'][0]['va:appDate']
        ).to eq(
          '2015-10-21' # Application Date is in Central Time
        )
      end
    end

    context 'with attachments' do
      context 'HCA attachment' do
        it 'creates the right result', run_at: '2019-01-11 14:19:04 -0800' do
          health_care_application = build(:hca_app_with_attachment)
          result = described_class.veteran_to_save_submit_form(health_care_application.parsed_form, nil, '10-10EZ')
          expect(result.to_json).to eq(get_fixture('hca/result_with_attachment').to_json)
        end
      end

      context 'Form1010Ezr attachment' do
        it 'creates the right result', run_at: '2024-06-27 18:22:17 -0800' do
          parsed_form = get_fixture('form1010_ezr/valid_form').merge(
            'attachments' => [
              {
                'confirmationCode' => create(:form1010_ezr_attachment).guid
              }
            ]
          )
          result = described_class.veteran_to_save_submit_form(parsed_form, nil, '10-10EZR')
          expect(result.to_json).to eq(get_fixture('form1010_ezr/result_with_attachment').to_json)
        end
      end

      context 'when a form attachment is not found based on the guid provided in the params' do
        it 'does not add an attachment', run_at: '2024-06-27 18:22:17 -0800' do
          parsed_form = get_fixture('form1010_ezr/valid_form').merge(
            'attachments' => [
              {
                'confirmationCode' => create(:form1010_ezr_attachment).guid
              },
              {
                # Bad guid that will not return an HCAAttachment nor a Form1010EzrAttachment
                'confirmationCode' => 'some-random-guid'
              }
            ]
          )
          result = described_class.veteran_to_save_submit_form(parsed_form, nil, '10-10EZR')
          expect(result['va:form']['va:attachments'].length).to eq(1)
          expect(result.to_json).to eq(get_fixture('form1010_ezr/result_with_attachment').to_json)
        end
      end
    end

    context 'EZ form submission' do
      it "sets the 'va:type' to '101' and 'va:value' to '1010EZR' for the va:formIdentifier object" do
        result = ez_form

        expect(result['va:form']['va:formIdentifier']['va:type']).to eq('100')
        expect(result['va:form']['va:formIdentifier']['va:value']).to eq('1010EZ')
      end
    end

    context 'EZR form submission' do
      it "sets the 'va:type' to '101' and 'va:value' to '1010EZR' for the va:formIdentifier object" do
        result = ezr_form

        expect(result['va:form']['va:formIdentifier']['va:type']).to eq('101')
        expect(result['va:form']['va:formIdentifier']['va:value']).to eq('1010EZR')
      end
    end
  end

  describe 'hca json schema' do
    it 'test application should pass json schema' do
      expect(test_veteran.to_json).to match_vets_schema('10-10EZ')
    end
  end

  describe '#veteran_to_military_service_info' do
    let(:veteran) do
      {
        'disabledInLineOfDuty' => true,
        'dischargeType' => 'general',
        'lastEntryDate' => '1980-03-07',
        'lastDischargeDate' => discharge_date.strftime('%Y-%m-%d'),
        'lastServiceBranch' => 'merchant seaman',
        'vaMedicalFacility' => '608'
      }
    end

    let(:expected) do
      {
        dischargeDueToDisability: true,
        militaryServiceSiteRecords: {
          militaryServiceSiteRecord: {
            militaryServiceEpisodes: {
              militaryServiceEpisode: {
                dischargeType: '',
                startDate: '03/07/1980',
                endDate: discharge_date.strftime('%m/%d/%Y'),
                serviceBranch: 7
              }
            },
            site: '608'
          }
        }
      }.deep_stringify_keys
    end

    context 'with a valid future discharge date' do
      subject { described_class.veteran_to_military_service_info(veteran) }

      let(:discharge_date) { Time.zone.today + 60.days }

      it 'properlies set discharge type and discharge date' do
        expect(described_class.veteran_to_military_service_info(veteran)).to eq(expected)
      end

      context 'with a discharge date of tomorrow', run_at: '2023-09-25 04:00:00' do
        let(:discharge_date) { Date.parse('2023-09-25') }

        it 'checks future discharge based on central time' do
          expect(described_class.veteran_to_military_service_info(veteran)).to eq(expected)
        end
      end
    end

    context 'with an edge case future discharge date' do
      subject { described_class.veteran_to_military_service_info(veteran) }

      let(:discharge_date) { Time.zone.today + 180.days }

      it 'properlies set discharge type and discharge date' do
        expect(described_class.veteran_to_military_service_info(veteran)).to eq(expected)
      end
    end

    context 'with an invalid future discharge date' do
      subject { described_class.veteran_to_military_service_info(veteran) }

      let(:discharge_date) { Time.zone.today + 181.days }

      it 'raises an invalid field exception' do
        expect { subject }.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#form_template' do
    let(:ez_template) do
      {
        'va:form' => {
          '@xmlns:va' => 'http://va.gov/schema/esr/voa/v1',
          'va:formIdentifier' => {
            'va:type' => '100',
            'va:value' => '1010EZ',
            'va:version' => 2_986_360_436
          }
        },
        'va:identity' => {
          '@xmlns:va' => 'http://va.gov/schema/esr/voa/v1',
          'va:authenticationLevel' => {
            'va:type' => '100',
            'va:value' => 'anonymous'
          }
        }
      }
    end
    let(:ezr_template) do
      {
        'va:form' => {
          '@xmlns:va' => 'http://va.gov/schema/esr/voa/v1',
          'va:formIdentifier' => {
            'va:type' => '101',
            'va:value' => '1010EZR',
            'va:version' => 2_986_360_436
          }
        },
        'va:identity' => {
          '@xmlns:va' => 'http://va.gov/schema/esr/voa/v1',
          'va:authenticationLevel' => {
            'va:type' => '100',
            'va:value' => 'anonymous'
          }
        }
      }
    end

    context "when the 'form_id' is '10-10EZR'" do
      it "sets the 'va:type' to '101' and 'va:value' to '1010EZR' for the va:formIdentifier object" do
        expect(described_class.form_template('10-10EZR')).to eq(ezr_template)
      end
    end

    context "when the 'form_id' anything other than '10-10EZR'" do
      it "sets the 'va:type' to '100' and 'va:value' to '1010EZ' for the va:formIdentifier object" do
        expect(described_class.form_template('hello world')).to eq(ez_template)
      end
    end
  end

  describe '#build_form_for_user' do
    let(:ez_form) { described_class.build_form_for_user(nil, '10-10EZ') }
    let(:ez_form_with_user) do
      described_class.build_form_for_user(HealthCareApplication.get_user_identifier(current_user), '10-10EZ')
    end
    let(:ezr_form) { described_class.build_form_for_user(nil, '10-10EZR') }

    context 'form template' do
      context 'when the submission is an EZ form' do
        it 'returns the form template for an EZ submission' do
          expect(ez_form).to eq(described_class.form_template('10-10EZ'))
        end
      end

      context 'when the submission is an EZR form' do
        it 'returns the form template for an EZR submission' do
          expect(ezr_form).to eq(described_class.form_template('10-10EZR'))
        end
      end
    end

    def self.should_return_ez_template
      it 'returns the form template for an EZ submission' do
        expect(ez_form).to eq(described_class.form_template('10-10EZ'))
      end
    end

    context 'with no user' do
      let(:current_user) { nil }

      should_return_ez_template
    end

    context 'with a user' do
      def self.should_return_user_id
        it 'includes the user id in the authentication level' do
          expect(ez_form_with_user).to eq(form_with_user)
        end
      end

      let(:current_user) { build(:user, icn: nil, edipi: nil) }
      let(:user_id) { '123' }
      let(:icn_id) { 1 }
      let(:edipi_id) { 2 }
      let(:auth_type_id) { nil }
      let(:form_with_user) do
        {
          'va:form' => {
            '@xmlns:va' => 'http://va.gov/schema/esr/voa/v1',
            'va:formIdentifier' => {
              'va:type' => '100',
              'va:value' => '1010EZ',
              'va:version' => 2_986_360_436
            }
          },
          'va:identity' => {
            '@xmlns:va' => 'http://va.gov/schema/esr/voa/v1',
            'va:authenticationLevel' => {
              'va:type' => '102',
              'va:value' => 'Assurance Level 2'
            },
            'va:veteranIdentifier' => { 'va:type' => auth_type_id, 'va:value' => '123' }
          }
        }
      end

      context 'when the user doesnt have an id' do
        should_return_ez_template
      end

      context 'when the user has an icn' do
        let(:auth_type_id) { icn_id }

        before do
          expect(current_user).to receive(:icn).and_return(user_id)
        end

        should_return_user_id

        context 'when the user has an edipi' do
          let(:auth_type_id) { icn_id }

          before do
            allow(current_user).to receive(:edipi).and_return('456')
          end

          should_return_user_id
        end
      end

      context 'when the user has an edipi' do
        let(:auth_type_id) { edipi_id }

        before do
          expect(current_user).to receive(:edipi).and_return(user_id)
        end

        should_return_user_id
      end

      context 'when the user has no icn or edipi' do
        before do
          allow(current_user).to receive_messages(icn: nil, edipi: nil)
        end

        it 'returns the form template for an EZ submission' do
          expect(ez_form_with_user).to eq(described_class.form_template('10-10EZ'))
        end
      end
    end
  end
end
