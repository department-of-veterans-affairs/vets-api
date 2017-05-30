# frozen_string_literal: true
require 'rails_helper'

RSpec.describe FormProfile, type: :model do
  describe '#initialize' do
    context 'with valid args' do
      let(:args) { { name: 'Benefits Summary Letter', letter_type: Letter::LETTER_TYPES[:benefits_summary] } }
      let(:letter) { Letter.new(args) }
      it 'builds a letter' do
        expect(letter.name).to eq(args[:name])
        expect(letter.letter_type).to eq('benefits_summary')
      end
    end

    context 'with missing arg' do
      let(:args) { { name: nil, letter_type: Letter::LETTER_TYPES[:benefits_summary] } }
      it 'raises an Argument error' do
        expect { Letter.new(args) }.to raise_error(ArgumentError, 'name and letter_type are required')
      end
    end

    context 'with invalid letter type' do
      let(:args) { { name: 'Benefits Summary Letter', letter_type: 'FOO' } }
      it 'raises an Argument error' do
        expect { Letter.new(args) }.to raise_error(ArgumentError, 'invalid letter type')
      end
    end
  end
end
