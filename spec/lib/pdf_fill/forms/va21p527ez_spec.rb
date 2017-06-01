# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/forms/va21p527ez'

describe PdfFill::Forms::VA21P527EZ do
  let(:form_data) do
    get_fixture('pdf_fill/21P-527EZ')
  end

  test_method(
    described_class,
    'get_disability_names',
    [
      [
        [nil],
        nil
      ],
      [
        [[
          { 'name' => 'name1' },
          { 'name' => 'name2' }
        ]],
        [
          'name2', 'name1'
        ]
      ],
      [
        [[
          { 'name' => 'name1' }
        ]],
        [
          nil, 'name1'
        ]
      ]
    ]
  )

  test_method(
    described_class,
    'rearrange_hospital_dates',
    [
      [
        [[
          0, 1, 2, 3, 4, 5
        ]],
        [
          3, 4, 1, 0, 2, 5
        ]
      ],
      [
        [[
          0, 1, nil, 3, 4, 5
        ]],
        [
          3, 4, 1, 0, nil, 5
        ]
      ]
    ]
  )

  test_method(
    described_class,
    'combine_va_hospital_dates',
    [
      [
        [[
          {}
        ]],
        [
          nil, nil, nil
        ]
      ],
      [
        [[
          {
            'dates' => ['2017']
          },
          {
            'dates' => ['2001', '2002', '2003']
          }
        ]],
        [
          '2017', nil, nil, '2001', '2002', '2003'
        ]
      ],
    ]
  )

  test_method(
    described_class,
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
    described_class,
    'combine_va_hospital_names',
    [
      [
        [[
          {
            'name' => 'hospital1',
            'location' => 'nyc'
          },
          {
            'name' => 'hospital2',
            'location' => 'dc'
          }
        ]],
        [
          'hospital1, nyc',
          'hospital2, dc'
        ]
      ]
    ]
  )

  test_method(
    described_class,
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
    described_class,
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
    described_class,
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
    described_class,
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
    described_class,
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
    described_class,
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

  it 'form data should match json schema' do
    expect(form_data.to_json).to match_vets_schema('21P-527EZ')
  end

  describe '#combine_full_name' do
    let(:full_name) do
      form_data['veteranFullName']
    end

    subject do
      described_class.combine_full_name(full_name)
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
      expect(described_class.merge_fields(form_data)).to eq(
        {"veteranFullName"=>"john middle smith Sr.",
         "nightPhone"=>"3456789",
         "dayPhone"=>"3456789",
         "veteranAddressLine1" => "street, street2",
         "email" => "foo@foo.com",
         "serviceBranch" => "army",
         "placeOfSeparation" => "city, state",
         "vaFileNumber"=>"c12345678",
         "cityState" => "Baltimore, MD, 21231, USA",
         "disabilities"=>[{"disabilityStartDate"=>"2016-12-01"}],
         "gender"=>"M",
         "genderMale"=>true,
         "genderFemale"=>false,
         "hasFileNumber"=>true,
         "noFileNumber"=>false,
         "altEmail" => "alt@foo.com",
         "nightPhoneAreaCode"=>"012",
         "dayPhoneAreaCode"=>"112",
         "vaHospitalTreatmentNames"=>["hospital1, nyc", "hospital2, dc"],
         "vaHospitalTreatmentDates"=>["2016-12-01", "2016-12-02", "2016-01-02", "2016-01-01", nil, "2016-12-03"],
         "disabilityNames"=>[nil, "disability 1"]}
      )
    end
  end
end
