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
  end
end
