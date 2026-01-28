# frozen_string_literal: true

require 'rails_helper'
require 'increase_compensation/ibm_converter'

RSpec.describe IncreaseCompensation::IbmConverter do
  describe '#convert' do
    it 'converts a blank obj into a blank list of keys' do
      key_file = File.read File.join(__dir__, 'ibm_keys_blank.json')
      keys = JSON.parse(key_file)
      expect(described_class.convert({})).to eq(keys)
    end

    it 'converts a Claims parsed_form to the Keys and formats expected by IBM' do
      converted = File.read File.join(__dir__, 'ibm_keys_filled.json')
      parsed_form = File.read File.join(__dir__, 'mock_parsed_form.json')

      expect(described_class.convert(JSON.parse(parsed_form))).to eq(JSON.parse(converted))
    end
  end

  describe '#extract_first_char' do
    it 'returns the 1st charatcher of a string' do
      expect(described_class.extract_first_char('Bender')).to eq('B')
    end

    it 'returns blank stirng if given blank/nil' do
      expect(described_class.extract_first_char('')).to eq('')
    end

    it 'returns blank string if given nil' do
      expect(described_class.extract_first_char(nil)).to eq('')
    end
  end

  describe '#format_date' do
    it 'changes date string from YYYY-MM-DD to MM/DD/YYYY' do
      expect(described_class.format_date('1975-03-15')).to eq('03/15/1975')
      expect(described_class.format_date('')).to eq('')
      expect(described_class.format_date(nil)).to eq('')
    end
  end

  describe '#full_name' do
    it 'concats the veterans name' do
      vets_name = {
        'first' => 'Philip',
        'middleinitial' => 'Joshua',
        'last' => 'Fry'
      }
      expect(described_class.full_name(vets_name)).to eq('Philip Joshua Fry')
      vets_name = { 'first' => 'Philip', 'last' => 'Fry' }
      expect(described_class.full_name(vets_name)).to eq('Philip Fry')
    end

    it 'returns a blank string if given nil/blank' do
      expect(described_class.full_name('')).to eq('')
      expect(described_class.full_name(nil)).to eq('')
      expect(described_class.full_name({})).to eq('')
    end
  end
end
