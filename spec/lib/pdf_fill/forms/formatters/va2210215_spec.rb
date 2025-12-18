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

    it 'handles empty programs array' do
      form_data = { 'programs' => [] }
      described_class.process_programs(form_data)
      expect(form_data['programs']).to eq([])
    end

    it 'handles program with empty fte hash' do
      form_data = {
        'programs' => [
          { 'name' => 'Program 1', 'fte' => {} }
        ]
      }
      expect { described_class.process_programs(form_data) }.not_to raise_error
      expect(form_data['programs'][0]['fte']).to eq({})
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

    it 'formats non-numeric string as -- when it converts to zero' do
      result = described_class.send(:format_numeric_fte_value, 'abc')
      expect(result).to eq('--')
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

    it 'formats non-numeric string as N/A when it converts to zero' do
      result = described_class.send(:format_percentage_fte_value, 'xyz')
      expect(result).to eq('N/A')
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

    it 'returns original string when phone number does not match pattern' do
      result = described_class.format_phone_number('123-456-7890')
      expect(result).to eq('123-456-7890')
    end

    it 'returns original string for invalid phone number format' do
      result = described_class.format_phone_number('12345')
      expect(result).to eq('12345')
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

    it 'returns replacement when non-numeric string converts to zero' do
      result = described_class.format_zero_as('abc', 'N/A')
      expect(result).to eq('N/A')
    end
  end

  describe '#sort_programs_by_name' do
    it 'sorts programs alphabetically by programName' do
      programs = [
        { 'programName' => 'Zebra Program', 'studentsEnrolled' => 100 },
        { 'programName' => 'Apple Program', 'studentsEnrolled' => 50 },
        { 'programName' => 'Banana Program', 'studentsEnrolled' => 75 }
      ]
      sorted = described_class.sort_programs_by_name(programs)
      expect(sorted.map { |p| p['programName'] }).to eq(['Apple Program', 'Banana Program', 'Zebra Program'])
    end

    it 'sorts case-insensitively' do
      programs = [
        { 'programName' => 'zebra', 'studentsEnrolled' => 100 },
        { 'programName' => 'Apple', 'studentsEnrolled' => 50 },
        { 'programName' => 'banana', 'studentsEnrolled' => 75 }
      ]
      sorted = described_class.sort_programs_by_name(programs)
      expect(sorted.map { |p| p['programName'] }).to eq(%w[Apple banana zebra])
    end

    it 'handles empty array' do
      programs = []
      sorted = described_class.sort_programs_by_name(programs)
      expect(sorted).to eq([])
    end

    it 'handles nil programs' do
      sorted = described_class.sort_programs_by_name(nil)
      expect(sorted).to eq([])
    end

    it 'handles programs with missing programName' do
      programs = [
        { 'programName' => 'Zebra', 'studentsEnrolled' => 100 },
        { 'studentsEnrolled' => 50 },
        { 'programName' => 'Apple', 'studentsEnrolled' => 75 }
      ]
      sorted = described_class.sort_programs_by_name(programs)
      # Programs with nil/missing programName sort first (empty string)
      expect(sorted.first['programName']).to be_nil
      expect(sorted[1]['programName']).to eq('Apple')
      expect(sorted.last['programName']).to eq('Zebra')
    end

    it 'handles nil programName values' do
      programs = [
        { 'programName' => 'Zebra', 'studentsEnrolled' => 100 },
        { 'programName' => nil, 'studentsEnrolled' => 50 },
        { 'programName' => 'Apple', 'studentsEnrolled' => 75 }
      ]
      sorted = described_class.sort_programs_by_name(programs)
      # Programs with nil programName sort first (empty string)
      expect(sorted.first['programName']).to be_nil
      expect(sorted[1]['programName']).to eq('Apple')
      expect(sorted.last['programName']).to eq('Zebra')
    end

    it 'maintains stable sort for programs with same name' do
      programs = [
        { 'programName' => 'Apple', 'studentsEnrolled' => 100 },
        { 'programName' => 'Banana', 'studentsEnrolled' => 50 },
        { 'programName' => 'Apple', 'studentsEnrolled' => 75 }
      ]
      sorted = described_class.sort_programs_by_name(programs)
      expect(sorted.map { |p| p['programName'] }).to eq(%w[Apple Apple Banana])
      # Verify original order is maintained for duplicates
      expect(sorted[0]['studentsEnrolled']).to eq(100)
      expect(sorted[1]['studentsEnrolled']).to eq(75)
    end

    it 'preserves all program data after sorting' do
      programs = [
        { 'programName' => 'Zebra', 'studentsEnrolled' => 100, 'supportedStudents' => 20 },
        { 'programName' => 'Apple', 'studentsEnrolled' => 50, 'supportedStudents' => 10 }
      ]
      sorted = described_class.sort_programs_by_name(programs)
      expect(sorted.first['programName']).to eq('Apple')
      expect(sorted.first['studentsEnrolled']).to eq(50)
      expect(sorted.first['supportedStudents']).to eq(10)
      expect(sorted.last['programName']).to eq('Zebra')
      expect(sorted.last['studentsEnrolled']).to eq(100)
      expect(sorted.last['supportedStudents']).to eq(20)
    end

    it 'handles programName as number' do
      programs = [
        { 'programName' => 123, 'studentsEnrolled' => 100 },
        { 'programName' => 'Apple', 'studentsEnrolled' => 50 }
      ]
      sorted = described_class.sort_programs_by_name(programs)
      expect(sorted.first['programName']).to eq(123)
      expect(sorted.last['programName']).to eq('Apple')
    end
  end
end
