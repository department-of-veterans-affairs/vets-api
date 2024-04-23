# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::Strings do
  describe '#filter_ascii_characters' do
    context 'when the input is a string that contains only ASCII 7 bit printable characters and tabs' do
      it 'returns the same string if it contains only ASCII characters' do
        expect(described_class.filter_ascii_characters("Hello,\t World!")).to eq("Hello,\t World!")
      end
    end

    context 'when the input is a string that contains non ASCII 7 bit characters' do
      it 'filters out non ASCII 7 bit characters' do
        expect(described_class.filter_ascii_characters('Hëllö, Wørld!')).to eq('Hll, Wrld!')
      end
    end

    context 'when the input is not a string' do
      it 'returns the input as is' do
        expect(described_class.filter_ascii_characters(12_345)).to eq(12_345)
      end
    end

    context 'when the input is nil' do
      it 'returns nil' do
        expect(described_class.filter_ascii_characters(nil)).to be_nil
      end
    end
  end
end
