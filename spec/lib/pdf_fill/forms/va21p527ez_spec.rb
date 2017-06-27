# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/forms/va21p527ez'

def basic_class
  PdfFill::Forms::VA21P527EZ.new({})
end

describe PdfFill::Forms::VA21P527EZ do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/21P-527EZ/kitchen_sink')
  end

  describe '#expand_expected_incomes' do
    it 'should create an expectedIncomes array' do
      expect(described_class.new(
        'expectedIncome' => {
          'salary' => 1
        }
      ).expand_expected_incomes).to eq(
        [
          {
            'recipient' => 'Myself',
            'source' => 'GROSS WAGES AND SALARY',
            'amount' => 1
          },
          nil,
          { 'recipient' => 'Myself', 'amount' => 0 },
          nil,
          nil,
          nil
        ]
      )
    end
  end

  describe '#expand_monthly_incomes' do
    it 'should create monthlyIncomes array' do
      expect(described_class.new(
        'monthlyIncome' => {
          'socialSecurity' => 1
        }
      ).expand_monthly_incomes).to eq(
        [{ 'recipient' => 'Myself', 'source' => 'SOCIAL SECURITY', 'amount' => 1 },
         nil,
         { 'recipient' => 'Myself', 'amount' => 0 },
         { 'recipient' => 'Myself', 'amount' => 0 },
         { 'recipient' => 'Myself', 'amount' => 0 },
         { 'recipient' => 'Myself', 'amount' => 0 },
         { 'recipient' => 'Myself', 'amount' => 0 },
         nil,
         nil,
         nil]
      )
    end
  end

  describe '#expand_net_worths' do
    it 'should create an netWorths array' do
      expect(described_class.new(
        'netWorth' => {
          'bank' => 1
        }
      ).expand_net_worths).to eq(
        [{ 'recipient' => 'Myself', 'source' => 'CASH/NON-INTEREST BEARING BANK ACCOUNTS', 'amount' => 1 },
         { 'recipient' => 'Myself', 'amount' => 0 },
         { 'recipient' => 'Myself', 'amount' => 0 },
         { 'recipient' => 'Myself', 'amount' => 0 },
         { 'recipient' => 'Myself', 'amount' => 0 },
         {},
         {},
         nil]
      )
    end
  end

  describe '#expand_bank_acct' do
    let(:bank_account) do
      {
        'accountNumber' => '88888888888',
        'routingNumber' => '123456789'
      }
    end

    subject do
      basic_class.expand_bank_acct(bank_account)
    end

    context 'when bank account is blank' do
      let(:bank_account) { nil }

      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with savings account' do
      before do
        bank_account['accountType'] = 'savings'
      end

      it 'should return savings account values' do
        expect(subject).to eq(
          'hasChecking' => false, 'hasSavings' => true, 'savingsAccountNumber' => '88888888888'
        )
      end
    end

    context 'with checking account' do
      before do
        bank_account['accountType'] = 'checking'
      end

      it 'should return checking account values' do
        expect(subject).to eq(
          'hasChecking' => true, 'hasSavings' => false, 'checkingAccountNumber' => '88888888888'
        )
      end
    end
  end

  test_method(
    basic_class,
    'expand_financial_acct',
    [
      [
        [
          nil, nil, nil
        ],
        nil
      ],
      [
        [
          'person',
          {
            'salary' => 1,
            'interest' => 2,
            'additionalSources' => [
              {
                'amount' => 3,
                'name' => 'name1'
              },
              {
                'amount' => 4,
                'name' => 'name2'
              }
            ]
          },
          {
            'salary' => [],
            'additionalSources' => [],
            'interest' => []
          }
        ],
        { 'salary' =>
  [{ 'recipient' => 'person', 'source' => 'GROSS WAGES AND SALARY', 'amount' => 1 }],
          'additionalSources' =>
  [{ 'recipient' => 'person', 'amount' => 3, 'additionalSourceName' => 'name1' },
   { 'recipient' => 'person', 'amount' => 4, 'additionalSourceName' => 'name2' }],
          'interest' =>
  [{ 'recipient' => 'person',
     'source' => 'TOTAL DIVIDENDS AND INTEREST',
     'amount' => 2 }] }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_marriages',
    [
      [
        [{}, :a],
        nil
      ],
      [
        [
          {
            a: [{
              'spouseFullName' => {
                'first' => 'spouse1',
                'last' => 'Olson'
              },
              'otherExplanation' => 'other'
            }]
          },
          :a
        ],
        { :a => [{ 'spouseFullName' => 'spouse1 Olson', 'otherExplanation' => 'other' }], 'aExplanations' => 'other' }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_marital_status',
    [
      [
        [{}, :a],
        nil
      ],
      [
        [{ a: 'Married' }, :a],
        { :a => 'Married', 'maritalStatusMarried' => true }
      ],
      [
        [{ a: 'Never Married' }, :a],
        { :a => 'Never Married', 'maritalStatusNeverMarried' => true }
      ],
      [
        [{ a: 'Separated' }, :a],
        { :a => 'Separated', 'maritalStatusSeparated' => true }
      ],
      [
        [{ a: 'Widowed' }, :a],
        { :a => 'Widowed', 'maritalStatusWidowed' => true }
      ],
      [
        [{ a: 'Divorced' }, :a],
        { :a => 'Divorced', 'maritalStatusDivorced' => true }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_date_range',
    [
      [
        [nil, 'foo'],
        nil
      ],
      [
        [{}, 'foo'],
        nil
      ],
      [
        [
          {
            'foo' => {
              'from' => '2001',
              'to' => '2002'
            }
          },
          'foo'
        ],
        { 'fooStart' => '2001', 'fooEnd' => '2002' }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_jobs',
    [
      [
        [nil],
        nil
      ],
      [
        [[
          { 'dateRange' => { 'from' => '2012-04-01', 'to' => '2013-05-01' },
            'employer' => 'job1',
            'address' => { 'city' => 'city1',
                           'country' => 'USA',
                           'postalCode' => '21231',
                           'state' => 'MD',
                           'street' => 'str1' },
            'annualEarnings' => 10,
            'jobTitle' => 'worker1',
            'daysMissed' => '1' },
          { 'dateRange' => { 'from' => '2012-04-02', 'to' => '2013-05-02' },
            'employer' => 'job2',
            'address' => { 'city' => 'city2',
                           'country' => 'USA',
                           'postalCode' => '21231',
                           'state' => 'MD',
                           'street' => 'str2' },
            'annualEarnings' => 20,
            'jobTitle' => 'worker2',
            'daysMissed' => '2' }
        ]],
        [{ 'annualEarnings' => 10,
           'jobTitle' => 'worker1',
           'daysMissed' => '1',
           'dateRangeStart' => '2012-04-01',
           'dateRangeEnd' => '2013-05-01',
           'nameAndAddr' => 'job1, str1, city1, MD, 21231, USA' },
         { 'annualEarnings' => 20,
           'jobTitle' => 'worker2',
           'daysMissed' => '2',
           'dateRangeStart' => '2012-04-02',
           'dateRangeEnd' => '2013-05-02',
           'nameAndAddr' => 'job2, str2, city2, MD, 21231, USA' }]
      ]
    ]
  )

  test_method(
    basic_class,
    'combine_previous_names',
    [
      [
        [[
          {
            'first' => 'first1',
            'last' => 'last'
          },
          {
            'first' => 'first2',
            'last' => 'last'
          }
        ]],
        'first1 last, first2 last'
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_severance_pay',
    [
      [
        [nil],
        {
          'hasSeverancePay' => false,
          'noSeverancePay' => true
        }
      ],
      [
        { 'amount' => 1 },
        {
          'hasSeverancePay' => true,
          'noSeverancePay' => false
        }
      ],
      [
        { 'amount' => 0 },
        {
          'hasSeverancePay' => false,
          'noSeverancePay' => true
        }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_previous_names',
    [
      [
        [1],
        {
          'hasPreviousNames' => true,
          'noPreviousNames' => false
        }
      ]
    ]
  )

  test_method(
    basic_class,
    'split_phone',
    [
      [
        '0123456789',
        %w(012 3456789)
      ],
      [
        [nil],
        [nil, nil]
      ]
    ]
  )

  test_method(
    basic_class,
    'combine_address',
    [
      [
        [nil],
        nil
      ],
      [
        {
          'street' => 'street',
          'street2' => 'street2'
        },
        'street, street2'
      ]
    ]
  )

  test_method(
    basic_class,
    'combine_city_state',
    [
      [
        [nil],
        nil
      ],
      [
        {
          'city' => 'foo',
          'state' => 'GA',
          'postalCode' => '12345',
          'country' => 'USA'
        },
        'foo, GA, 12345, USA'
      ]
    ]
  )

  test_method(
    basic_class,
    'combine_hash',
    [
      [
        [nil, []],
        nil
      ],
      [
        [
          { 'a' => '1', 'b' => '2' },
          %w(a b)
        ],
        '1 2'
      ],
      [
        [
          { 'a' => '1', 'c' => '2' },
          %w(a b c)
        ],
        '1 2'
      ],
      [
        [
          { 'a' => '1', 'b' => '2' },
          %w(a b),
          ','
        ],
        '1,2'
      ]
    ]
  )

  test_method(
    basic_class,
    'combine_full_address',
    [
      [
        {
          'city' => 'Baltimore',
          'country' => 'USA',
          'postalCode' => '21231',
          'street' => 'street',
          'street2' => 'street2',
          'state' => 'MD'
        },
        'street, street2, Baltimore, MD, 21231, USA'
      ]
    ]
  )

  test_method(
    basic_class,
    'combine_name_addr',
    [
      [
        [nil],
        nil
      ],
      [
        {
          'name' => 'name',
          'address' => {
            'city' => 'Baltimore',
            'country' => 'USA',
            'postalCode' => '21231',
            'street' => 'street',
            'street2' => 'street2',
            'state' => 'MD'
          }
        },
        { 'nameAndAddr' => 'name, street, street2, Baltimore, MD, 21231, USA' }
      ]
    ]
  )

  test_method(
    basic_class,
    'combine_hash_and_del_keys',
    [
      [
        [nil, 1, 2],
        nil
      ],
      [
        [{ a: '1', b: '2' }, %i(a b), :ab],
        { ab: '1 2' }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_gender',
    [
      [
        'M',
        {
          'genderMale' => true,
          'genderFemale' => false
        }
      ],
      [
        'F',
        {
          'genderMale' => false,
          'genderFemale' => true
        }
      ],
      [
        [nil],
        {}
      ]
    ]
  )

  test_method(
    basic_class,
    'replace_phone',
    [
      [
        [{}, 'foo'],
        nil
      ],
      [
        [nil, 'foo'],
        nil
      ],
      [
        [{ 'foo' => '5551110000' }, 'foo'],
        { 'foo' => '1110000', 'fooAreaCode' => '555' }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_children',
    [
      [
        [{}, nil],
        nil
      ],
      [
        [
          {
            children: [
              {
                'dependentRelationship' => 'child',
                'childFullName' => {
                  'first' => 'outside1',
                  'last' => 'Olson'
                },
                'childAddress' => {
                  'city' => 'city1',
                  'country' => 'USA',
                  'postalCode' => '21231',
                  'state' => 'MD',
                  'street' => 'str1'
                },
                'childNotInHousehold' => true
              },
              {
                'dependentRelationship' => 'child',
                'childFullName' => {
                  'first' => 'outside1',
                  'last' => 'Olson'
                },
                'childAddress' => {
                  'city' => 'city1',
                  'country' => 'USA',
                  'postalCode' => '21231',
                  'state' => 'MD',
                  'street' => 'str1'
                }
              }
            ]
          },
          :children
        ],
        { :children =>
  [{ 'dependentRelationship' => 'child',
     'childFullName' => { 'first' => 'outside1', 'last' => 'Olson' },
     'childAddress' => 'str1, city1, MD, 21231, USA',
     'childNotInHousehold' => true,
     'personWhoLivesWithChild' => nil },
   { 'dependentRelationship' => 'child',
     'childFullName' => { 'first' => 'outside1', 'last' => 'Olson' },
     'childAddress' => 'str1, city1, MD, 21231, USA',
     'personWhoLivesWithChild' => nil }],
          'children' => [],
          'outsideChildren' =>
  [{ 'dependentRelationship' => 'child',
     'childFullName' => { 'first' => 'outside1', 'last' => 'Olson' },
     'childAddress' => 'str1, city1, MD, 21231, USA',
     'childNotInHousehold' => true,
     'personWhoLivesWithChild' => nil },
   { 'dependentRelationship' => 'child',
     'childFullName' => { 'first' => 'outside1', 'last' => 'Olson' },
     'childAddress' => 'str1, city1, MD, 21231, USA',
     'personWhoLivesWithChild' => nil }] }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_checkbox',
    [
      [
        [true, 'Foo'],
        {
          'hasFoo' => true,
          'noFoo' => false
        }
      ],
      [
        [false, 'Foo'],
        {
          'hasFoo' => false,
          'noFoo' => true
        }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_va_file_number',
    [
      [
        '123',
        {
          'hasFileNumber' => true,
          'noFileNumber' => false
        }
      ],
      [
        [nil],
        {
          'hasFileNumber' => false,
          'noFileNumber' => true
        }
      ]
    ]
  )

  describe '#combine_full_name' do
    let(:full_name) do
      form_data['veteranFullName']
    end

    subject do
      basic_class.combine_full_name(full_name)
    end

    context 'with missing fields' do
      before do
        full_name.delete('middle')
        full_name.delete('suffix')
      end

      it 'should combine a full name' do
        expect(subject).to eq('john smith')
      end
    end

    context 'with nil full name' do
      let(:full_name) { nil }

      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    it 'should combine a full name' do
      expect(subject).to eq('john middle smith Sr.')
    end
  end

  describe '#merge_fields' do
    it 'should merge the right fields' do
      expect(described_class.new(form_data).merge_fields).to eq(
        get_fixture('pdf_fill/21P-527EZ/merge_fields')
      )
    end
  end
end
