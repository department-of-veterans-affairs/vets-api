# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/reference_range_formatter'

RSpec.describe UnifiedHealthData::ReferenceRangeFormatter do
  describe '.format' do
    it 'returns empty string when referenceRange is nil' do
      obs = {}
      result = described_class.format(obs)
      expect(result).to eq('')
    end

    it 'returns text directly when available' do
      obs = {
        'referenceRange' => [
          { 'text' => '70-110 mg/dL' },
          { 'text' => '<=3' }
        ]
      }
      result = described_class.format(obs)
      expect(result).to eq('70-110 mg/dL, <=3')
    end

    it 'formats low-high values correctly' do
      obs = {
        'referenceRange' => [
          {
            'low' => { 'value' => 13.5, 'unit' => 'g/dL' },
            'high' => { 'value' => 18.0, 'unit' => 'g/dL' }
          }
        ]
      }
      result = described_class.format(obs)
      expect(result).to eq('13.5 - 18.0 g/dL')
    end

    it 'formats low-only values correctly' do
      obs = {
        'referenceRange' => [
          {
            'low' => { 'value' => 94 }
          }
        ]
      }
      result = described_class.format(obs)
      expect(result).to eq('>= 94')
    end

    it 'formats high-only values correctly' do
      obs = {
        'referenceRange' => [
          {
            'high' => { 'value' => 44 }
          }
        ]
      }
      result = described_class.format(obs)
      expect(result).to eq('<= 44')
    end

    it 'handles empty low/high values gracefully' do
      obs = {
        'referenceRange' => [
          {
            'low' => {},
            'high' => {}
          }
        ]
      }
      result = described_class.format(obs)
      expect(result).to eq('')
    end

    it 'handles mixed formats correctly' do
      obs = {
        'referenceRange' => [
          { 'text' => 'Normal: <100 mg/dL' },
          {
            'low' => { 'value' => 5.0 },
            'high' => { 'value' => 7.5 }
          },
          {
            'low' => { 'value' => 4.0 }
          }
        ]
      }
      result = described_class.format(obs)
      expect(result).to eq('Normal: <100 mg/dL, 5.0 - 7.5, >= 4.0')
    end

    it 'gracefully handles malformed reference range data' do
      # Test with various types of malformed data
      test_cases = [
        # Nil reference range
        { 'referenceRange' => nil },

        # Empty array
        { 'referenceRange' => [] },

        # Non-array reference range
        { 'referenceRange' => 'not an array' },

        # Array with non-hash elements
        { 'referenceRange' => ['string', 123, nil] }
      ]

      test_cases.each do |test_case|
        result = described_class.format(test_case)
        expect(result).to eq(''), "Failed for test case: #{test_case.inspect}"
      end
    end

    it 'handles type field that is not a hash' do
      test_case = { 'referenceRange' => [{ 'low' => { 'value' => 10 }, 'type' => 'not a hash' }] }
      result = described_class.format(test_case)
      expect(result).to eq('>= 10')
    end

    it 'handles missing low and high fields' do
      test_case = { 'referenceRange' => [{ 'other_field' => 'some value' }] }
      result = described_class.format(test_case)
      expect(result).to eq('')
    end

    it 'handles non-numeric values in low/high' do
      test_case = { 'referenceRange' => [{ 'low' => { 'value' => 'not a number' },
                                           'high' => { 'value' => 'also not a number' } }] }
      result = described_class.format(test_case)
      expect(result).to eq('')
    end

    it 'handles malformed nested structures' do
      test_case = { 'referenceRange' => [{ 'low' => 'not a hash', 'high' => 123 }] }
      result = described_class.format(test_case)
      expect(result).to eq('')
    end

    it 'handles low value with no unit and type with no text' do
      test_case = { 'referenceRange' => [{ 'low' => { 'value' => 5 }, 'type' => { 'coding' => [{}] } }] }
      result = described_class.format(test_case)
      expect(result).to eq('>= 5')
    end

    it 'handles multiple reference ranges with different types' do
      obs = {
        'referenceRange' => [
          {
            'low' => { 'value' => 14, 'unit' => 'mL' },
            'high' => { 'value' => 20, 'unit' => 'mL' },
            'type' => {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                  'code' => 'normal',
                  'display' => 'Normal Range'
                }
              ],
              'text' => 'Normal Range'
            }
          },
          {
            'low' => { 'value' => 1000, 'unit' => 'mg/dL' },
            'high' => { 'value' => 2000, 'unit' => 'mg/dL' },
            'type' => {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                  'code' => 'critical',
                  'display' => 'Critical Range'
                }
              ],
              'text' => 'Critical Range'
            }
          }
        ]
      }
      result = described_class.format(obs)
      expect(result).to eq('Normal Range: 14 - 20 mL, Critical Range: 1000 - 2000 mg/dL')
    end

    it 'handles multiple high-only reference ranges with different types' do
      obs = {
        'referenceRange' => [
          {
            'high' => { 'value' => 20 },
            'type' => {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                  'code' => 'normal',
                  'display' => 'Normal Range'
                }
              ],
              'text' => 'Normal Range'
            }
          },
          {
            'high' => { 'value' => 2000 },
            'type' => {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                  'code' => 'critical',
                  'display' => 'Critical Range'
                }
              ],
              'text' => 'Critical Range'
            }
          }
        ]
      }
      result = described_class.format(obs)
      expect(result).to eq('Normal Range: <= 20, Critical Range: <= 2000')
    end
  end
end
