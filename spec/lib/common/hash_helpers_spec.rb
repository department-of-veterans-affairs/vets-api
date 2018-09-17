# frozen_string_literal: true

require 'rails_helper'

describe Common::HashHelpers do
  describe '#deep_compact' do
    it 'should deep compact a hash' do
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

    it 'should compact nested arrays' do
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
