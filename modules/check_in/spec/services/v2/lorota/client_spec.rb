# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Client do
  subject { described_class.build(check_in:) }

  let(:check_in) do
    CheckIn::V2::Session.build(data: { uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d', dob: '1970-02-20',
                                       last_name: 'last' })
  end

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

    context 'when called dob in session model' do
      let(:auth_param_with_dob) do
        { lastName: 'last', dob: '1970-02-20' }
      end

      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)
      end

      it 'uses dob in auth_params to call lorota endpoint' do
        expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything) do |&block|
          result = block.call(Faraday::Request.new)
          expect(result).to eq(auth_param_with_dob.to_json)
        end

        subject.token
      end
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
      expect(subject.data(token:)).to eq(faraday_response)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:get).with(anything).and_yield(Faraday::Request.new)

      subject.data(token:)
    end
  end
end
