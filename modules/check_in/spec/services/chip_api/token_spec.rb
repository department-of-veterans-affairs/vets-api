# frozen_string_literal: true

require 'rails_helper'

describe ChipApi::Token do
  subject { described_class }

  describe 'attributes' do
    it 'responds to request' do
      expect(subject.build.respond_to?(:request)).to be(true)
    end

    it 'responds to claims_token' do
      expect(subject.build.respond_to?(:claims_token)).to be(true)
    end

    it 'responds to access_token' do
      expect(subject.build.respond_to?(:access_token)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Token' do
      expect(subject.build).to be_an_instance_of(ChipApi::Token)
    end
  end

  describe '#fetch' do
    let(:token) do
      'eyJraWQiOiJRMFZKbEt0TU9rYUxXTEtxdXhsTllHQzFRLWMtblQzYjRWVlJLaXB4TThzIiwiYWxnIj'
    end
    let(:faraday_response) { double('Faraday::Response', body: { 'token' => token }.to_json) }

    before do
      allow_any_instance_of(ChipApi::Request).to receive(:post).with(anything).and_return(faraday_response)
    end

    it 'returns an instance of Token' do
      expect(subject.build.fetch).to be_an_instance_of(subject)
    end

    it 'has an access_token value' do
      expect(subject.build.fetch.access_token).to eq(token)
    end
  end

  describe '#created_at' do
    it 'is an Integer' do
      expect(subject.build.created_at).to be_a(Integer)
    end
  end

  describe '#ttl_duration' do
    it 'is a set number' do
      expect(subject.build.ttl_duration).to eq(900)
    end
  end

  describe '#chip_api' do
    it 'returns chip_api config' do
      expect(subject.build.chip_api).to be_a(Config::Options)
    end
  end

  describe '#base_path' do
    it 'returns base_path' do
      expect(subject.build.chip_api.base_path).to eq('dev')
    end
  end
end
