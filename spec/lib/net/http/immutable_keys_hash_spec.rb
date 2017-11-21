# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe Net::HTTP::ImmutableKeysHash do
  subject { Net::HTTP::ImmutableKeysHash.new }

  describe '#[]' do
    it 'returns self for downcase' do
      subject['foo'] = 'bar'
      expect(subject['foo']).to eq('bar')
      expect(subject.keys.first).to be_a(Net::HTTP::ImmutableHeaderKey)
    end
  end
end
