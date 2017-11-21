# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe Net::HTTP::ImmutableHeaderKey do
  subject { Net::HTTP::ImmutableHeaderKey.new('va_auth_foo') }

  describe '#downcase' do
    it 'returns self for downcase' do
      expect(subject.downcase).to eq(subject)
    end
  end

  describe '#capitalize' do
    it 'returns self for capitalize' do
      expect(subject.capitalize).to eq(subject)
    end
  end

  describe '#capitalize!' do
    it 'returns self for capitalize!' do
      expect(subject.capitalize!).to eq(subject)
    end
  end

  describe '#to_s' do
    it 'returns self for to_s' do
      expect(subject.to_s).to eq(subject)
    end
  end

  describe '#split' do
    it 'returns self for split' do
      expect(subject.split('_')).to eq([subject])
    end
  end
end
