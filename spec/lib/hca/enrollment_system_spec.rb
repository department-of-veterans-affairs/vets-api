# frozen_string_literal: true
require 'rails_helper'
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
  }

  let(:test_address) { TEST_ADDRESS.dup }

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
        [
          {
            'phoneNumber' => '1234',
            'type' => '1'
          }
        ]
      ],
      [
        {
          'mobilePhone' => '1234'
        },
        [
          {
            'phoneNumber' => '1234',
            'type' => '4'
          }
        ]
      ],
      [
        {
          'homePhone' => '1234',
          'mobilePhone' => '4'
        },
        [
          {
            'phoneNumber' => '1234',
            'type' => '1'
          },
          {
            'phoneNumber' => '4',
            'type' => '4'
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
        {
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
        },
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
end
