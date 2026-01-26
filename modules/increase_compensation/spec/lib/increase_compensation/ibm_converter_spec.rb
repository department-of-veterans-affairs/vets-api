# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncreaseCompensation::IbmConverter do
  subject { dummy_class.new }

  let(:dummy_class) { Class.new { include IncreaseCompensation::IbmConverter } }

  describe '#convert' do
    it 'converts a Claims parsed_form to the Keys and formats expected by IBM' do
      expect(subject.convert({})).to eq({})
    end
  end

  describe '#extract_first_char' do
    it 'returns the 1st charatcher of a string' do
      expect(subject.extract_first_char('Bender')).to eq('B')
    end

    it 'returns blank stirng if given blank' do
      expect(subject.extract_first_char('')).to eq('')
    end

    it 'returns blank string if given nil' do
      expect(subject.extract_first_char(nil)).to eq('')
    end
  end

  describe '#format_date' do
    it 'changes date string to MM/DD/YYYY' do
      expect(subject.format_date('1975-03-15')).to eq('03/15/1975')
    end
  end

  describe '#full_name' do
    it 'concats the veterans name' do
      vets_name = {
        'first' => 'Philip',
        'middleinitial' => 'Joshua',
        'last' => 'Fry'
      }
      expect(subject.full_name(vets_name)).to eq('Philip Joshua Fry')
      vets_name = { 'first' => 'Philip', 'last' => 'Fry' }
      expect(subject.full_name(vets_name)).to eq('Philip Fry')
    end
  end
end
