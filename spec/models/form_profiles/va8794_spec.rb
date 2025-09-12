# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormProfiles::VA8794, type: :model do
  subject { described_class.new }

  describe '#metadata' do
    let(:expected_metadata) do
      {
        version: 0,
        prefill: true,
        returnUrl: '/applicant/information'
      }
    end

    it 'returns the correct metadata hash' do
      expect(subject.metadata).to eq(expected_metadata)
    end

    it 'returns metadata with correct version' do
      expect(subject.metadata[:version]).to eq(0)
    end

    it 'returns metadata with prefill enabled' do
      expect(subject.metadata[:prefill]).to be true
    end

    it 'returns metadata with correct return URL' do
      expect(subject.metadata[:returnUrl]).to eq('/applicant/information')
    end

    it 'returns a hash with exactly 3 keys' do
      expect(subject.metadata.keys).to contain_exactly(:version, :prefill, :returnUrl)
    end

    it 'returns metadata that is a hash' do
      expect(subject.metadata).to be_a(Hash)
    end

    it 'returns metadata with symbol keys' do
      subject.metadata.each_key do |key|
        expect(key).to be_a(Symbol)
      end
    end
  end

  describe 'inheritance' do
    it 'inherits from FormProfile' do
      expect(described_class.superclass).to eq(FormProfile)
    end
  end
end
