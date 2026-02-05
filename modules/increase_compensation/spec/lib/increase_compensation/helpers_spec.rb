# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncreaseCompensation::Helpers do
  subject { dummy_class.new }

  let(:dummy_class) { Class.new { include IncreaseCompensation::Helpers } }

  describe '#split_currency_amount_thousands' do
    it 'returns empty hash for zero, nil, negative, or too large amounts' do
      expect(subject.split_currency_amount_thousands(nil)).to eq({})
      expect(subject.split_currency_amount_thousands(-1)).to eq({})
      expect(subject.split_currency_amount_thousands(1_000_000)).to eq({})
    end

    it 'returns hash with 2 left spaced values if greater than 999' do
      expect(subject.split_currency_amount_thousands(1250)).to eq({ 'firstThree' => '  1', 'lastThree' => '250' })
    end

    it 'returns hash of 1 value if less than 1000' do
      expect(subject.split_currency_amount_thousands(500)).to eq({ 'lastThree' => '500' })
      expect(subject.split_currency_amount_thousands(0)).to eq({ 'lastThree' => '  0' })
    end
  end

  describe '#format_custom_boolean' do
    it 'returns Off' do
      expect(subject.format_custom_boolean(nil)).to eq('Off')
      expect(subject.format_custom_boolean('')).to eq('Off')
    end

    it 'returns YES or custom value' do
      expect(subject.format_custom_boolean(true)).to eq('YES')
      expect(subject.format_custom_boolean(true, 'YES, explain')).to eq('YES, explain')
    end

    it 'returns No or custom values' do
      expect(subject.format_custom_boolean(false)).to eq('NO')
      expect(subject.format_custom_boolean(false, 'YES', 'No, explain')).to eq('No, explain')
    end
  end

  describe '#two_line_overflow' do
    it 'returns {} if the string is blank' do
      expect(subject.two_line_overflow('', 'test', 8)).to eq({})
    end

    it 'returns hash of 2 lines if over limit' do
      expect(subject.two_line_overflow('Too long String', 'test',
                                       8)).to eq({ 'test1' => 'Too long', 'test2' => ' String' })
    end

    it 'return hash of 1 line if under limit' do
      expect(subject.two_line_overflow('Under Limit', 'test', 12)).to eq({ 'test1' => 'Under Limit' })
    end
  end

  describe '#map_date_range' do
    it 'splits the dates in a range into month,day,year' do
      dates = { 'from' => '2025-01-01', 'to' => '2025-02-02' }
      expect(subject.map_date_range(dates)).to eq(
        {
          'from' => {
            'month' => '01',
            'day' => '01',
            'year' => '2025'
          },
          'to' => {
            'month' => '02',
            'day' => '02',
            'year' => '2025'
          }
        }
      )
    end

    it 'returns {} if date range is nil or has no from date' do
      expect(subject.map_date_range({})).to eq({})
      expect(subject.map_date_range(nil)).to eq({})
    end
  end

  describe '#split_date_without_day' do
    it 'splits a yyyy-mm sting into a year, month, and day hash' do
      expect(subject.split_date_without_day('2021/11')).to eq({ 'month' => '11', 'day' => '', 'year' => '2021' })
      expect(subject.split_date_without_day('2021-11')).to eq({ 'month' => '11', 'day' => '', 'year' => '2021' })
      expect(subject.split_date_without_day('11-2021')).to eq({ 'month' => '11', 'day' => '', 'year' => '2021' })
      expect(subject.split_date_without_day('11/2021')).to eq({ 'month' => '11', 'day' => '', 'year' => '2021' })
      expect(subject.split_date_without_day('')).to eq({})
      expect(subject.split_date_without_day(nil)).to eq({})
      expect(subject.split_date_without_day('11/2021/33')).to eq({})
      expect(subject.split_date_without_day('2021-11-05')).to eq({})
    end
  end

  describe '#format_first_care_item' do
    it 'formats to write 1 single item to form' do
      care_item =
        {
          'inVANetwork' => true,
          'nameAndAddressOfHospital' => 'Cheyenne VA Medical Center, 789 Health Ave, Cheyenne, WY 82001',
          'hospitalTreatmentDates' => [
            {
              'from' => '2024-01',
              'to' => '2024-02'
            }
          ]
        }
      expect(subject.format_first_care_item(care_item)).to eq(
        [
          {
            'from' => {
              'month' => '01', 'day' => '', 'year' => '2024'
            },
            'to' => {
              'month' => '02', 'day' => '', 'year' => '2024'
            }
          },
          'VA - Cheyenne VA Medical Center, 789 Health Ave, Cheyenne, WY 82001'
        ]
      )
    end

    it 'overflows if more than one date range' do
      care_item =
        {
          'nameAndAddressOfHospital' => 'Cheyenne VA Medical Center, 789 Health Ave, Cheyenne, WY 82001',
          'hospitalTreatmentDates' => [
            {
              'from' => '2024-06-01',
              'to' => '2024-06-15'
            },
            { 'from' => '2024-06-01' }
          ]
        }
      expect(subject.format_first_care_item(care_item)).to eq(
        [
          {
            'from' => {
              'year' => "from: 2024-06-01, to: 2024-06-15\nfrom: 2024-06-01, to: \n"
            }
          },
          'Non-VA - Cheyenne VA Medical Center, 789 Health Ave, Cheyenne, WY 82001'
        ]
      )
    end
  end

  describe '#overflow_doc_and_hospitals' do
    doctors_care = [
      {
        'inVANetwork' => true,
        'doctorsTreatmentDates' => [
          { 'from' => '2024-01-10',
            'to' => '2025-02-20' }
        ],
        'nameAndAddressOfDoctor' => 'Dr. Carl Jenkins, 456 Medical St, Cheyenne, WY 82001',
        'relatedDisability' => ['PTSD']
      },
      {
        'inVANetwork' => false,
        'doctorsTreatmentDates' => [
          { 'from' => '2024-01-10',
            'to' => '2025-02-20' },
          { 'from' => '2024-01-10' }
        ],
        'nameAndAddressOfDoctor' => 'Dr.Nick, 123 frontage St, Cheyenne, WY 82001'
      },
      {
        'doctorsTreatmentDates' => [
          { 'from' => '2024-01-10',
            'to' => '2025-02-20' },
          { 'from' => '2024-01-10',
            'to' => '2025-02-20' }
        ],
        'nameAndAddressOfDoctor' => 'Dr. Zoidberg, 423 main St, Cheyenne, WY 82001'
      }
    ]
    it 'formats all items for overflow' do
      expect(subject.overflow_doc_and_hospitals(doctors_care, true)).to eq(
        [
          "VA - Dr. Carl Jenkins, 456 Medical St, Cheyenne, WY 82001\nTreated for: PTSD\nFrom: 2024-01-10, To: 2025-02-20\n", # rubocop:disable Layout/LineLength
          "Non-VA - Dr.Nick, 123 frontage St, Cheyenne, WY 82001\nFrom: 2024-01-10, To: 2025-02-20\nFrom: 2024-01-10, To: \n", # rubocop:disable Layout/LineLength
          "Non-VA - Dr. Zoidberg, 423 main St, Cheyenne, WY 82001\nFrom: 2024-01-10, To: 2025-02-20\nFrom: 2024-01-10, To: 2025-02-20\n" # rubocop:disable Layout/LineLength
        ]
      )
    end
  end

  describe '#resolve_boolean_checkbox' do
    it 'take a true and returns YES' do
      expect(subject.resolve_boolean_checkbox(true)).to eq('YES')
    end

    it 'take a false and returns NO' do
      expect(subject.resolve_boolean_checkbox(false)).to eq('NO')
    end

    it 'take a nil and returns OFF' do
      expect(subject.resolve_boolean_checkbox(nil)).to eq('OFF')
    end
  end
end
