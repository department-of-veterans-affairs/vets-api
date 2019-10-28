# frozen_string_literal: true

require 'rails_helper'

describe Common::HashHelpers do
  describe '#deep_remove_blanks' do
    it 'recursively removes blanks' do
      hash = {
        a: [
          nil,
          '',
          false,
          {
            a: 1,
            b: nil,
            c: false,
            d: ' '
          }
        ]
      }

      expect(described_class.deep_remove_blanks(hash)).to eq(
        a: [false, { a: 1, c: false }]
      )
    end
  end

  describe '#deep_compact' do
    it 'deeps compact a hash' do
      hash = {
        a: '',
        b: nil,
        c: {
          d: nil
        }
      }

      expect(described_class.deep_compact(hash)).to eq(
        a: '', c: {}
      )
    end

    it 'compacts nested arrays' do
      hash = {
        a: [
          nil,
          {
            a: 1,
            b: nil
          }
        ]
      }

      expect(described_class.deep_compact(hash)).to eq(
        a: [{ a: 1 }]
      )
    end
  end
end
