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

    let(:faraday_response) { double('Faraday::Response', status: 200, body:) }

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

    it 'returns code param as a string when auth code is included in request parameters' do
      success_params = ActionController::Parameters.new(code: '1234')

      expect(subject.get_auth_code(success_params.permit(:code))).to eq('1234')
    end

    it 'raises errors when auth code is not included in request parameters' do
      error_params = ActionController::Parameters.new(error: 'error', error_details: 'details')
      expect { subject.get_auth_code(error_params) }.to raise_error(missing_auth_error)

      empty_params = ActionController::Parameters.new
      expect { subject.get_auth_code(empty_params) }.to raise_error(missing_auth_error)

      random_params = ActionController::Parameters.new(random_param: '')
      expect { subject.get_auth_code(random_params) }.to raise_error(missing_auth_error)
    end
  end

  describe 'revoke_token' do
    response_body_for_401 = {
      errors: [
        {
          errorType: 'invalid_token',
          message: 'Access token invalid: refresh_token_value.'
        }
      ],
      success: false
    }
    let(:revocation_response_200) { double('Faraday::Response', status: 200) }
    let(:revocation_response_400) { double('Faraday::Response', status: 400, body: 'unsuccessful response') }
    let(:revocation_response_401) { double('Faraday::Response', status: 401, body: response_body_for_401.to_json) }

    token = { access_token: 'access_token_value', refresh_token: 'refresh_token_value' }

    it 'returns true if token was successfully revoked' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(revocation_response_200)
      expect(subject.revoke_token(token).nil?).to be(true)
    end

    it 'returns TokenRevocationError when fitbit returns 400' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(revocation_response_400)
      expect { subject.revoke_token(token) }.to raise_error(DhpConnectedDevices::Fitbit::TokenRevocationError)
    end

    it 'returns true if token was manually revoked by user through the Fitbit UI' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(revocation_response_401)
      expect(subject.revoke_token(token).nil?).to be(true)
    end
  end
end
