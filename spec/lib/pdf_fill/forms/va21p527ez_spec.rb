# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va21p527ez'

def basic_class
  PdfFill::Forms::Va21p527ez.new({})
end

describe PdfFill::Forms::Va21p527ez do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/21P-527EZ/kitchen_sink')
  end

  let(:default_account) do
    { 'name' => 'None', 'amount' => 0, 'recipient' => 'None' }
  end

  let(:default_additional_account) do
    {
      'additionalSourceName' => 'None',
      'amount' => 0,
      'recipient' => 'None',
      'sourceAndAmount' => 'None: $0'
    }
  end

  describe '#expand_expected_incomes' do
    it 'creates an expectedIncomes array' do
      expect(described_class.new(
        'expectedIncome' => {
          'salary' => 1
        }
      ).expand_expected_incomes).to eq(
        [{ 'recipient' => 'Myself', 'sourceAndAmount' => 'Gross wages and salary: $1', 'amount' => 1 },
         default_account,
         default_account,
         default_account,
         default_additional_account,
         default_additional_account]
      )
    end
  end

  describe '#expand_monthly_incomes' do
    it 'creates monthlyIncomes array' do
      expect(described_class.new(
        'monthlyIncome' => {
          'socialSecurity' => 1
        }
      ).expand_monthly_incomes).to eq(
        [{ 'recipient' => 'Myself', 'sourceAndAmount' => 'Social security: $1', 'amount' => 1 },
         default_account,
         default_account,
         default_account,
         default_account,
         default_account,
         default_account,
         default_account,
         default_additional_account,
         default_additional_account]
      )
    end
  end

  describe '#expand_net_worths' do
    it 'creates an netWorths array' do
      expect(described_class.new(
        'netWorth' => {
          'bank' => 1
        }
      ).expand_net_worths).to eq(
        [{ 'recipient' => 'Myself', 'sourceAndAmount' => 'Cash/non-interest bearing bank accounts: $1', 'amount' => 1 },
         default_account,
         default_account,
         default_account,
         default_account,
         default_account,
         default_account,
         default_account]
      )
    end
  end

  describe '#expand_bank_acct' do
    subject do
      described_class.new({}).expand_bank_acct(bank_account)
    end

    let(:bank_account) do
      {
        'accountNumber' => '88888888888',
        'routingNumber' => '123456789'
      }
    end

    context 'when bank account is blank' do
      let(:bank_account) { nil }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with savings account' do
      before do
        bank_account['accountType'] = 'savings'
      end

      it 'returns savings account values' do
        expect(subject).to eq(
          'hasChecking' => false, 'hasSavings' => true, 'savingsAccountNumber' => '88888888888'
        )
      end
    end

    context 'with checking account' do
      before do
        bank_account['accountType'] = 'checking'
      end

      it 'returns checking account values' do
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
        {
          'salary' => [{ 'recipient' => 'person', 'sourceAndAmount' => 'Gross wages and salary: $1', 'amount' => 1 }],
          'additionalSources' => [
            {
              'recipient' => 'person',
              'amount' => 3,
              'sourceAndAmount' => 'Name1: $3',
              'additionalSourceName' => 'name1'
            },
            {
              'recipient' => 'person',
              'amount' => 4, 'sourceAndAmount' => 'Name2: $4', 'additionalSourceName' => 'name2'
            }
          ],
          'interest' => [
            { 'recipient' => 'person', 'sourceAndAmount' => 'Total dividends and interest: $2', 'amount' => 2 }
          ]
        }
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
        { a: [{ 'spouseFullName' => 'spouse1 Olson',
                'otherExplanation' => 'other',
                'reasonForSeparation' => 'Marriage has not been terminated',
                'otherExplanations' => 'other' }] }
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

  describe '#expand_jobs' do
    it 'expands the jobs data' do
      expect(
        JSON.parse(
          described_class.new({}).expand_jobs(
            [
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
            ]
          ).to_json
        )
      ).to eq(
        [{ 'employer' => 'job1',
           'address' => {
             'city' => 'city1', 'country' => 'USA', 'postalCode' => '21231', 'state' => 'MD', 'street' => 'str1'
           },
           'annualEarnings' => 10,
           'jobTitle' => 'worker1',
           'daysMissed' => '1',
           'nameAndAddr' => {
             'value' => 'job1, str1, city1, MD, 21231, USA', 'extras_value' => "job1\nstr1\ncity1, MD, 21231\nUSA"
           },
           'dateRangeStart' => '2012-04-01',
           'dateRangeEnd' => '2013-05-01' },
         { 'employer' => 'job2',
           'address' => {
             'city' => 'city2', 'country' => 'USA', 'postalCode' => '21231', 'state' => 'MD', 'street' => 'str2'
           },
           'annualEarnings' => 20,
           'jobTitle' => 'worker2',
           'daysMissed' => '2',
           'nameAndAddr' => {
             'value' => 'job2, str2, city2, MD, 21231, USA', 'extras_value' => "job2\nstr2\ncity2, MD, 21231\nUSA"
           },
           'dateRangeStart' => '2012-04-02',
           'dateRangeEnd' => '2013-05-02' }]
      )
    end
  end

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
        %w[012 3456789]
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
          %w[a b]
        ],
        '1 2'
      ],
      [
        [
          { 'a' => '1', 'c' => '2' },
          %w[a b c]
        ],
        '1 2'
      ],
      [
        [
          { 'a' => '1', 'b' => '2' },
          %w[a b],
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

  describe '#combine_name_addr' do
    it 'combines name addr in both formats' do
      expect(
        JSON.parse(
          basic_class.combine_name_addr(
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
            }
          ).to_json
        )
      ).to eq(
        'value' => 'name, street, street2, Baltimore, MD, 21231, USA',
        'extras_value' => "name\nstreet\nstreet2\nBaltimore, MD, 21231\nUSA"
      )
    end
  end

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

  describe '#expand_children' do
    it 'formats children correctly' do
      expect(
        JSON.parse(
          described_class.new({}).expand_children(
            {
              children: [
                {
                  'childFullName' => {
                    'first' => 'outside1',
                    'last' => 'Olson'
                  },
                  'childAddress' => {
                    'city' => 'city1',
                    'country' => 'USA',
                    'postalCode' => '21232',
                    'state' => 'MD',
                    'street' => 'str1'
                  },
                  'childNotInHousehold' => true
                },
                {
                  'childFullName' => {
                    'first' => 'outside1',
                    'last' => 'Olson'
                  },
                  'childAddress' => {
                    'city' => 'city1',
                    'country' => 'USA',
                    'postalCode' => '21233',
                    'state' => 'MD',
                    'street' => 'str1'
                  }
                }
              ]
            },
            :children
          ).to_json
        )
      ).to eq(
        'children' =>
    [{ 'childFullName' => { 'first' => 'outside1', 'last' => 'Olson' },
       'childAddress' => { 'value' => 'str1, city1, MD, 21232, USA', 'extras_value' => "str1\ncity1, MD, 21232\nUSA" },
       'childNotInHousehold' => true,
       'personWhoLivesWithChild' => nil },
     { 'childFullName' => { 'first' => 'outside1', 'last' => 'Olson' },
       'childAddress' => { 'value' => 'str1, city1, MD, 21233, USA', 'extras_value' => "str1\ncity1, MD, 21233\nUSA" },
       'personWhoLivesWithChild' => nil }],
        'outsideChildren' =>
    [{ 'childFullName' => { 'first' => 'outside1', 'last' => 'Olson' },
       'childAddress' => { 'value' => 'str1, city1, MD, 21232, USA', 'extras_value' => "str1\ncity1, MD, 21232\nUSA" },
       'childNotInHousehold' => true,
       'personWhoLivesWithChild' => nil },
     { 'childFullName' => { 'first' => 'outside1', 'last' => 'Olson' },
       'childAddress' => { 'value' => 'str1, city1, MD, 21233, USA', 'extras_value' => "str1\ncity1, MD, 21233\nUSA" },
       'personWhoLivesWithChild' => nil }]
      )
    end
  end

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
    subject do
      described_class.new({}).combine_full_name(full_name)
    end

    let(:full_name) do
      form_data['veteranFullName']
    end

    context 'with missing fields' do
      before do
        full_name.delete('middle')
        full_name.delete('suffix')
      end

      it 'combines a full name' do
        expect(subject).to eq('john smith')
      end
    end

    context 'with nil full name' do
      let(:full_name) { nil }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end

    it 'combines a full name' do
      expect(subject).to eq('john middle smith Sr.')
    end
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture('pdf_fill/21P-527EZ/merge_fields').to_json
      )
    end
  end
end
