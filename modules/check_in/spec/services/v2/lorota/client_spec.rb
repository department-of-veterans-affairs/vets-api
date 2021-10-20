# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Client do
  subject { described_class.build(check_in: check_in) }

  let(:check_in) { CheckIn::V2::Session.build(uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d') }

  describe 'attributes' do
    it 'responds to claims_token' do
      expect(subject.respond_to?(:claims_token)).to be(true)
    end

    it 'responds to check_in' do
      expect(subject.respond_to?(:check_in)).to be(true)
    end

    it 'responds to settings' do
      expect(subject.respond_to?(:settings)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Client' do
      expect(subject).to be_an_instance_of(V2::Lorota::Client)
    end
  end

  describe '#token' do
    let(:token) do
      'eyJraWQiOiJRMFZKbEt0TU9rYUxXTEtxdXhsTllHQzFRLWMtblQzYjRWVlJLaXB4TThzIiwiYWxnIj'
    end
    let(:faraday_response) { double('Faraday::Response', body: { 'token' => token }.to_json) }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
    end

    it 'returns the token' do
      expect(subject.token).to eq(faraday_response)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_yield(Faraday::Request.new)

      subject.token
    end
  end

  describe '#data' do
    let(:token) do
      'eyJraWQiOiJRMFZKbEt0TU9rYUxXTEtxdXhsTllHQzFRLWMtblQzYjRWVlJLaXB4TThzIiwiYWxnIj'
    end
    let(:faraday_response) { double('Faraday::Response') }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything).and_return(faraday_response)
    end

    it 'returns a valid response' do
      expect(subject.data(token: token)).to eq(faraday_response)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:get).with(anything).and_yield(Faraday::Request.new)

      subject.data(token: token)
    end
  end
end
