# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MPI::Type::DateTimeString do
  subject(:type) { described_class.new }

  describe '#cast' do
    context 'when given a valid ISO8601 string' do
      let(:iso_string) { '2025-06-03T09:30:00Z' }

      it 'returns the same string' do
        expect(type.cast(iso_string)).to eq(iso_string)
      end
    end

    context 'when given a parseable non‑ISO8601 string' do
      let(:parseable_string) { 'June 3, 2025 09:30:00' }

      it 'returns the original string' do
        expect(type.cast(parseable_string)).to eq(parseable_string)
      end
    end

    context 'when given an invalid datetime string' do
      let(:invalid_string) { 'not a date' }

      it 'returns nil' do
        expect(type.cast(invalid_string)).to be_nil
      end
    end

    context 'when given an empty string' do
      let(:empty_string) { '' }

      it 'returns nil' do
        expect(type.cast(empty_string)).to be_nil
      end
    end

    context 'when given a non‑string value' do
      let(:numeric_value) { 12_345 }

      it 'returns nil' do
        expect(type.cast(numeric_value)).to be_nil
      end
    end
  end
end
