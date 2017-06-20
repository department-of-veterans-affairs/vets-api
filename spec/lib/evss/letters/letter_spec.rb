# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EVSS::Letters::Letter, type: :model do
  describe '#initialize' do
    context 'with valid args' do
      let(:letter) { build(:letter) }
      it 'builds a letter' do
        expect(letter.name).to eq('Benefits Summary Letter')
        expect(letter.letter_type).to eq('benefit_summary')
      end
    end

    context 'with missing arg' do
      let(:args) { { 'letter_name' => nil, 'letter_type' => 'benefit_summary' } }
      it 'raises an Argument error' do
        expect { EVSS::Letters::Letter.new(args) }.to raise_error(ArgumentError, 'name and letter_type are required')
      end
    end

    context 'with invalid letter type' do
      let(:args) { { 'letter_name' => 'Benefits Summary Letter', 'letter_type' => 'FOO' } }
      it 'raises an Argument error' do
        expect { EVSS::Letters::Letter.new(args) }.to raise_error(ArgumentError, 'invalid letter type: FOO')
      end
    end
  end
end
