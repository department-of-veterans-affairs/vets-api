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
        user_id: '1FAKE' }.to_json
    end

    let(:faraday_response) { double('Faraday::Response', body: body) }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
    end

    it 'returns the body' do
      expect(subject.get_token('auth_code')).to eq(faraday_response)
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
end
