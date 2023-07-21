# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountAccessToken, type: :model do
  let(:service_account_access_token) do
    create(:service_account_access_token,
           service_account_id:,
           audience:,
           user_identifier:,
           scopes:,
           expiration_time:,
           version:,
           created_time:)
  end

  let(:service_account_id) { service_account_config.service_account_id }
  let!(:service_account_config) { create(:service_account_config) }
  let(:audience) { 'some-audience' }
  let(:user_identifier) { 'some-user-identifier' }
  let(:scopes) { [scope] }
  let(:scope) { 'some-scope' }
  let(:version) { SignIn::Constants::AccessToken::CURRENT_VERSION }
  let(:validity_length) { service_account_config.access_token_duration }
  let(:expiration_time) { Time.zone.now + validity_length }
  let(:created_time) { Time.zone.now }

  describe 'validations' do
    describe '#service_account_id' do
      subject { service_account_access_token.service_account_id }

      context 'when service_account_id is nil' do
        let(:service_account_id) { nil }
        let(:expected_error_message) { "Validation failed: Service account can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#audience' do
      subject { service_account_access_token.audience }

      context 'when audience is nil' do
        let(:audience) { nil }
        let(:expected_error_message) { "Validation failed: Audience can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#user_identifier' do
      subject { service_account_access_token.user_identifier }

      context 'when user_identifier is nil' do
        let(:user_identifier) { nil }
        let(:expected_error_message) { "Validation failed: User identifier can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#version' do
      subject { service_account_access_token.version }

      context 'when version is arbitrary' do
        let(:version) { 'some-arbitrary-version' }
        let(:expected_error_message) { 'Validation failed: Version is not included in the list' }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when version is nil' do
        let(:version) { nil }
        let(:expected_version) { SignIn::Constants::AccessToken::CURRENT_VERSION }

        it 'sets version to CURRENT_VERSION' do
          expect(subject).to be expected_version
        end
      end
    end

    describe '#expiration_time' do
      subject { service_account_access_token.expiration_time }

      before { Timecop.freeze }

      after { Timecop.return }

      context 'when expiration_time is nil' do
        let(:expiration_time) { nil }
        let(:expected_expiration_time) { Time.zone.now + validity_length }

        it 'sets expired time to VALIDITY_LENGTH_SHORT_MINUTES from now' do
          expect(subject).to eq(expected_expiration_time)
        end
      end
    end

    describe '#created_time' do
      subject { service_account_access_token.created_time }

      before { Timecop.freeze }

      after { Timecop.return }

      context 'when created_time is nil' do
        let(:created_time) { nil }
        let(:expected_created_time) { Time.zone.now }

        it 'sets expired time to now' do
          expect(subject).to eq(expected_created_time)
        end
      end
    end
  end

  describe '#to_s' do
    subject { service_account_access_token.to_s }

    let(:expected_hash) do
      {
        uuid: service_account_access_token.uuid,
        service_account_id: service_account_access_token.service_account_id,
        user_identifier: service_account_access_token.user_identifier,
        scopes: service_account_access_token.scopes,
        audience: service_account_access_token.audience,
        version: service_account_access_token.version,
        created_time: service_account_access_token.created_time.to_i,
        expiration_time: service_account_access_token.expiration_time.to_i
      }
    end

    it 'returns a hash of expected values' do
      expect(subject).to eq(expected_hash)
    end
  end
end
