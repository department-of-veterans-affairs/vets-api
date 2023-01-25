# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ClientConfig, type: :model do
  let(:client_id) { SignIn::Constants::Auth::MOBILE_CLIENT }

  describe 'validations' do
    describe '#initialize' do
      subject { SignIn::ClientConfig.new(client_id: client_id) }

      context 'when client_id is nil' do
        let(:client_id) { nil }
        let(:expected_error_message) { 'Validation failed: Client can\'t be blank, Client is not included in the list' }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when client_id is not in CLIENT_IDS constant' do
        let(:client_id) { 'some-arbitrary-client-id' }
        let(:expected_error_message) { 'Validation failed: Client is not included in the list' }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end

  shared_examples 'client config methods' do
    let(:client_config) { SignIn::ClientConfig.new(client_id: client_id) }

    describe '#cookie_auth?' do
      it 'matches expected cookie auth value' do
        expect(client_config.cookie_auth?).to eq(expected_values[:cookie_auth])
      end
    end

    describe '#api_auth?' do
      it 'matches expected api auth value' do
        expect(client_config.api_auth?).to eq(expected_values[:api_auth])
      end
    end

    describe '#anti_csrf?' do
      it 'matches expected anti csrf value' do
        expect(client_config.anti_csrf?).to eq(expected_values[:anti_csrf])
      end
    end

    describe '#redirect_uri' do
      it 'matches expected redirect uri value' do
        expect(client_config.redirect_uri).to eq(expected_values[:redirect_uri])
      end
    end

    describe '#access_token_duration' do
      it 'matches expected access token duration value' do
        expect(client_config.access_token_duration).to eq(expected_values[:access_token_duration])
      end
    end

    describe '#access_token_audience' do
      it 'matches expected access token audience value' do
        expect(client_config.access_token_audience).to eq(expected_values[:access_token_audience])
      end
    end

    describe '#refresh_token_duration' do
      it 'matches expected refresh token duration value' do
        expect(client_config.refresh_token_duration).to eq(expected_values[:refresh_token_duration])
      end
    end
  end

  describe 'client config methods' do
    context 'mobile auth' do
      let(:client_id) { SignIn::Constants::Auth::MOBILE_CLIENT }
      let(:expected_values) do
        { cookie_auth: false,
          api_auth: true,
          anti_csrf: false,
          redirect_uri: 'vamobile://login-success',
          access_token_duration: 30.minutes,
          access_token_audience: 'vamobile',
          refresh_token_duration: 45.days }
      end

      it_behaves_like 'client config methods'
    end

    context 'web auth' do
      let(:client_id) { SignIn::Constants::Auth::WEB_CLIENT }
      let(:expected_values) do
        { cookie_auth: true,
          api_auth: false,
          anti_csrf: true,
          redirect_uri: 'http://localhost:3001/auth/login/callback',
          access_token_duration: 5.minutes,
          access_token_audience: 'va.gov',
          refresh_token_duration: 30.minutes }
      end

      it_behaves_like 'client config methods'
    end

    context 'mobile test auth' do
      let(:client_id) { SignIn::Constants::Auth::MOBILE_TEST_CLIENT }
      let(:expected_values) do
        { cookie_auth: false,
          api_auth: true,
          anti_csrf: false,
          redirect_uri: 'http://localhost:4001/auth/sis/login-success',
          access_token_duration: 30.minutes,
          access_token_audience: 'vamobile',
          refresh_token_duration: 45.days }
      end

      it_behaves_like 'client config methods'
    end
  end
end
