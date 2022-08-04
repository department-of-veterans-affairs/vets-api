# frozen_string_literal: true

require 'rails_helper'
require 'fitbit/client'

RSpec.describe DhpConnectedDevices::Fitbit::Client do
  subject { described_class.new }

  describe 'get_token' do
    let(:body) do
      { access_token: 'short',
        expires_in: 28_800,
        refresh_token: 'short',
        scope: 'heartrate activity sleep nutrition',
        token_type: 'Bearer',
        user_id: '1FAKE' }.to_json.to_s
    end

    let(:faraday_response) { double('Faraday::Response', status: 200, body: body) }

    context 'successful response from fitbit' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'returns the body as a hash' do
        result = subject.get_token('auth_code')

        expect(result[:access_token]).to eq('short')
        expect(result[:refresh_token]).to eq('short')
        expect(result[:scope]).to eq('heartrate activity sleep nutrition')
        expect(result[:expires_in]).to eq(28_800)
      end
    end

    context 'unsuccessful fitbit response' do
      let(:faraday_response) { double('Faraday::Response', status: 404, body: 'unsuccessful response') }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'raises error when when is response is 404' do
        expect { subject.get_token('123') }.to raise_error(DhpConnectedDevices::Fitbit::TokenExchangeError)
      end
    end
  end

  describe 'auth_url_with_pkce' do
    it 'generates a fitbit url' do
      expect(subject.auth_url_with_pkce).to start_with('https://www.fitbit.com/oauth2/authorize?')
    end

    it 'contains client_id' do
      expect(subject.auth_url_with_pkce).to include('client_id=')
    end

    it 'contains response_type' do
      expect(subject.auth_url_with_pkce).to include('response_type=code')
    end

    it 'contains scope' do
      expect(subject.auth_url_with_pkce).to include('scope=')
    end

    it 'contains redirect_uri' do
      expect(subject.auth_url_with_pkce).to include('redirect_uri=')
    end

    it 'contains code_challenge' do
      expect(subject.auth_url_with_pkce).to include('code_challenge=')
    end

    it 'contains code_challenge_method' do
      expect(subject.auth_url_with_pkce).to include('code_challenge_method=')
    end
  end

  describe '.new' do
    it 'returns an instance of Fitbit client' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe 'get_auth_code' do
    let(:missing_auth_error) { DhpConnectedDevices::Fitbit::MissingAuthError }

    it 'returns code as a string when auth code given' do
      expect(subject.get_auth_code({ code: '1234' })).to eq('1234')
    end

    it 'raise errors when auth code not given' do
      error_params = { error: 'error', error_details: 'details' }

      expect { subject.get_auth_code(error_params) }.to raise_error(missing_auth_error)
      expect { subject.get_auth_code({}) }.to raise_error(missing_auth_error)
      expect { subject.get_auth_code({ random_param: '' }) }.to raise_error(missing_auth_error)
    end
  end
end
