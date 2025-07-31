# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va2210215'

describe PdfFill::Forms::Formatters::Va2210215 do
  describe '#combine_official_name' do
    it 'returns early when certifyingOfficial is nil' do
      form_data = {}
      described_class.combine_official_name(form_data)
      expect(form_data).to eq({})
    end

    it 'returns early when certifyingOfficial is empty' do
      form_data = { 'certifyingOfficial' => {} }
      described_class.combine_official_name(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to be_nil
    end

    it 'combines first and last name when both are present' do
      form_data = {
        'certifyingOfficial' => {
          'first' => 'John',
          'last' => 'Doe'
        }
      }
      described_class.combine_official_name(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to eq('John Doe')
    end

    it 'does not combine when first name is missing' do
      form_data = {
        'certifyingOfficial' => {
          'last' => 'Doe'
        }
      }
      described_class.combine_official_name(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to be_nil
    end

    it 'does not combine when last name is missing' do
      form_data = {
        'certifyingOfficial' => {
          'first' => 'John'
        }
      }
      described_class.combine_official_name(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to be_nil
    end
  end

  describe '#process_programs' do
    it 'returns early when programs is nil' do
      form_data = {}
      described_class.process_programs(form_data)
      expect(form_data).to eq({})
    end

    it 'processes programs without calculation date' do
      form_data = {
        'programs' => [
          { 'name' => 'Program 1' },
          { 'name' => 'Program 2' }
        ]
      }
      described_class.process_programs(form_data)
      expect(form_data['programs'][0]['programDateOfCalculation']).to be_nil
      expect(form_data['programs'][1]['programDateOfCalculation']).to be_nil
    end

    it 'assigns calculation date to all programs when present' do
      form_data = {
        'institutionDetails' => {
          'dateOfCalculations' => '2023-12-01'
        },
        'programs' => [
          { 'name' => 'Program 1' },
          { 'name' => 'Program 2' }
        ]
      }
      described_class.process_programs(form_data)
      expect(form_data['programs'][0]['programDateOfCalculation']).to eq('2023-12-01')
      expect(form_data['programs'][1]['programDateOfCalculation']).to eq('2023-12-01')
    end

    it 'processes fte data when present' do
      form_data = {
        'programs' => [
          {
            'name' => 'Program 1',
            'fte' => {
              'supported' => '5.5',
              'nonSupported' => '0',
              'totalFTE' => '10.25',
              'supportedPercentageFTE' => '55.5'
            }
          }
        ]
      }
      described_class.process_programs(form_data)
      expect(form_data['programs'][0]['fte']['supported']).to eq('5.50')
      expect(form_data['programs'][0]['fte']['nonSupported']).to eq('--')
      expect(form_data['programs'][0]['fte']['totalFTE']).to eq('10.25')
      expect(form_data['programs'][0]['fte']['supportedPercentageFTE']).to eq('55.50%')
    end
  end

  describe '#format_numeric_fte_value' do
    it 'formats numeric value correctly when non-zero' do
      result = described_class.send(:format_numeric_fte_value, '5.5')
      expect(result).to eq('5.50')
    end

    it 'formats numeric value as -- when zero' do
      result = described_class.send(:format_numeric_fte_value, '0')
      expect(result).to eq('--')
    end

    it 'formats numeric value as -- when zero as float' do
      result = described_class.send(:format_numeric_fte_value, '0.0')
      expect(result).to eq('--')
    end

    it 'formats decimal values with proper precision' do
      result = described_class.send(:format_numeric_fte_value, '3.456789')
      expect(result).to eq('3.46')
    end
  end

  describe '#format_percentage_fte_value' do
    it 'formats percentage value correctly when non-zero' do
      result = described_class.send(:format_percentage_fte_value, '75.5')
      expect(result).to eq('75.50%')
    end

    it 'formats percentage value as N/A when zero' do
      result = described_class.send(:format_percentage_fte_value, '0')
      expect(result).to eq('N/A')
    end

    it 'formats percentage value as N/A when zero as float' do
      result = described_class.send(:format_percentage_fte_value, '0.0')
      expect(result).to eq('N/A')
    end

    it 'formats percentage decimal values with proper precision' do
      result = described_class.send(:format_percentage_fte_value, '33.333')
      expect(result).to eq('33.33%')
    end
  end

  describe '#process_fte' do
    it 'formats supported field correctly' do
      fte = { 'supported' => '5.5' }
      described_class.process_fte(fte)
      expect(fte['supported']).to eq('5.50')
    end

    it 'formats supported field as -- when zero' do
      fte = { 'supported' => '0' }
      described_class.process_fte(fte)
      expect(fte['supported']).to eq('--')
    end

    it 'does not modify supported field when not present' do
      fte = {}
      described_class.process_fte(fte)
      expect(fte['supported']).to be_nil
    end

    it 'formats nonSupported field correctly' do
      fte = { 'nonSupported' => '3.25' }
      described_class.process_fte(fte)
      expect(fte['nonSupported']).to eq('3.25')
    end

    it 'formats nonSupported field as -- when zero' do
      fte = { 'nonSupported' => '0' }
      described_class.process_fte(fte)
      expect(fte['nonSupported']).to eq('--')
    end

    it 'formats totalFTE field correctly' do
      fte = { 'totalFTE' => '15.75' }
      described_class.process_fte(fte)
      expect(fte['totalFTE']).to eq('15.75')
    end

    it 'formats totalFTE field as -- when zero' do
      fte = { 'totalFTE' => '0' }
      described_class.process_fte(fte)
      expect(fte['totalFTE']).to eq('--')
    end

    it 'formats supportedPercentageFTE field correctly' do
      fte = { 'supportedPercentageFTE' => '75.5' }
      described_class.process_fte(fte)
      expect(fte['supportedPercentageFTE']).to eq('75.50%')
    end

    it 'formats supportedPercentageFTE field as N/A when zero' do
      fte = { 'supportedPercentageFTE' => '0' }
      described_class.process_fte(fte)
      expect(fte['supportedPercentageFTE']).to eq('N/A')
    end

    it 'processes all fields simultaneously' do
      fte = {
        'supported' => '5.5',
        'nonSupported' => '0',
        'totalFTE' => '10.25',
        'supportedPercentageFTE' => '55.0'
      }
      described_class.process_fte(fte)
      expect(fte['supported']).to eq('5.50')
      expect(fte['nonSupported']).to eq('--')
      expect(fte['totalFTE']).to eq('10.25')
      expect(fte['supportedPercentageFTE']).to eq('55.00%')
    end
  end

  describe '#format_phone_number' do
    it 'formats phone number correctly' do
      result = described_class.format_phone_number('1234567890')
      expect(result).to eq('(123) 456-7890')
    end
  end

  describe '#format_zero_as' do
    it 'returns replacement when value is zero' do
      result = described_class.format_zero_as(0, 'N/A')
      expect(result).to eq('N/A')
    end

    it 'returns original value when non-zero' do
      result = described_class.format_zero_as(5.5, 'N/A')
      expect(result).to eq(5.5)
    end

    it 'returns replacement when string zero' do
      result = described_class.format_zero_as('0', 'N/A')
      expect(result).to eq('N/A')
    end

    it 'returns replacement when float zero' do
      result = described_class.format_zero_as('0.0', 'N/A')
      expect(result).to eq('N/A')
    end
  end
end