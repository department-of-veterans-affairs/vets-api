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
      ],
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
      ],
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
          "spouseDateOfBirth" => "1980-04-06",
          "spouseFullName" => {
            "first" => "FirstSpouse",
            "middle" => "MiddleSpouse",
            "last" => "LastSpouse",
            "suffix" => "Sr."
          },
          "dateOfMarriage" => "1983-05-10",
          "spouseSocialSecurityNumber" => "111-22-1234",
        },
        {
          "dob"=>"04/06/1980",
          "givenName"=>"FIRSTSPOUSE",
          "middleName"=>"MIDDLESPOUSE",
          "familyName"=>"LASTSPOUSE",
          "suffix"=>"SR.",
          "relationship"=>2,
          "startDate"=>"05/10/1983",
          "ssns"=>{"ssn"=>{"ssnText"=>"111221234"}},
          "address"=> {
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
          "grossIncome" => 991.9,
          "netIncome" => 981.2,
          "otherIncome" => 91.9
        },
        {
          "income" => [
            {
              "amount" => 991.9,
              "type" => 7
            },
            {
              "amount" => 981.2,
              "type" => 13
            },
            {
              "amount" => 91.9,
              "type" => 10
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
        { "childEducationExpenses" => 1198.11 },
        {
          'expense' => [{
            'amount' => 1198.11,
            'expenseType' => '16'
          }]
        }
      ]
    ]
  )
end
