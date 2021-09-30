# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Token do
  subject { described_class.build(check_in: check_in) }

  let(:check_in) { CheckIn::V2::Session.build(uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d') }

  describe 'attributes' do
    it 'responds to request' do
      expect(subject.respond_to?(:request)).to be(true)
    end

    it 'responds to claims_token' do
      expect(subject.respond_to?(:claims_token)).to be(true)
    end

    it 'responds to access_token' do
      expect(subject.respond_to?(:access_token)).to be(true)
    end

    it 'responds to check_in' do
      expect(subject.respond_to?(:check_in)).to be(true)
    end

    it 'responds to settings' do
      expect(subject.respond_to?(:settings)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Token' do
      expect(subject).to be_an_instance_of(V2::Lorota::Token)
    end
  end

  describe '#fetch' do
    let(:token) do
      'eyJraWQiOiJRMFZKbEt0TU9rYUxXTEtxdXhsTllHQzFRLWMtblQzYjRWVlJLaXB4TThzIiwiYWxnIj'
    end
    let(:faraday_response) { double('Faraday::Response', body: { 'token' => token }.to_json) }

    before do
      allow_any_instance_of(V2::Lorota::Request).to receive(:post).with(anything, anything).and_return(faraday_response)
    end

    it 'returns an instance of Token' do
      expect(subject.fetch).to be_an_instance_of(V2::Lorota::Token)
    end

    it 'has an access_token value' do
      expect(subject.fetch.access_token).to eq(token)
    end
  end

  describe '#base_path' do
    it 'returns base_path' do
      expect(subject.base_path).to eq('dev')
    end
  end
end
