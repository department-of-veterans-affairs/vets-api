# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AccessToken, type: :model do
  let(:access_token) do
    create(:access_token,
           session_handle:,
           client_id:,
           user_uuid:,
           audience:,
           refresh_token_hash:,
           parent_refresh_token_hash:,
           anti_csrf_token:,
           last_regeneration_time:,
           expiration_time:,
           version:,
           created_time:,
           user_attributes:)
  end

  let(:session_handle) { create(:oauth_session).handle }
  let(:user_uuid) { create(:user_account).id }
  let!(:client_config) do
    create(:client_config, authentication:, access_token_duration:, access_token_attributes:)
  end
  let(:access_token_duration) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
  let(:access_token_attributes) { SignIn::Constants::AccessToken::USER_ATTRIBUTES }
  let(:client_id) { client_config.client_id }
  let(:audience) { 'some-audience' }
  let(:authentication) { SignIn::Constants::Auth::API }
  let(:refresh_token_hash) { SecureRandom.hex }
  let(:parent_refresh_token_hash) { SecureRandom.hex }
  let(:anti_csrf_token) { SecureRandom.hex }
  let(:last_regeneration_time) { Time.zone.now }
  let(:version) { SignIn::Constants::AccessToken::CURRENT_VERSION }
  let(:validity_length) { client_config.access_token_duration }
  let(:expiration_time) { Time.zone.now + validity_length }
  let(:created_time) { Time.zone.now }
  let(:first_name) { Faker::Name.first_name }
  let(:last_name) { Faker::Name.last_name }
  let(:email) { Faker::Internet.email }
  let(:user_attributes) { { 'first_name' => first_name, 'last_name' => last_name, 'email' => email } }

  describe 'validations' do
    describe '#session_handle' do
      subject { access_token.session_handle }

      context 'when session_handle is nil' do
        let(:session_handle) { nil }
        let(:expected_error_message) { "Validation failed: Session handle can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#client_id' do
      subject { access_token.client_id }

      context 'when client_id is nil' do
        let(:client_id) { nil }
        let(:expected_error_message) { "Validation failed: Client can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#audience' do
      subject { access_token.audience }

      context 'when audience is nil' do
        let(:audience) { nil }
        let(:expected_error_message) { "Validation failed: Audience can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#user_uuid' do
      subject { access_token.user_uuid }

      context 'when user_uuid is nil' do
        let(:user_uuid) { nil }
        let(:expected_error_message) { "Validation failed: User uuid can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#refresh_token_hash' do
      subject { access_token.refresh_token_hash }

      context 'when refresh_token_hash is nil' do
        let(:refresh_token_hash) { nil }
        let(:expected_error_message) { "Validation failed: Refresh token hash can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#anti_csrf_token' do
      subject { access_token.anti_csrf_token }

      context 'when anti_csrf_token is nil' do
        let(:anti_csrf_token) { nil }
        let(:expected_error_message) { "Validation failed: Anti csrf token can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#last_regeneration_time' do
      subject { access_token.last_regeneration_time }

      context 'when last_regeneration_time is nil' do
        let(:last_regeneration_time) { nil }
        let(:expected_error_message) { "Validation failed: Last regeneration time can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#version' do
      subject { access_token.version }

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
      subject { access_token.expiration_time }

      before { Timecop.freeze }

      after { Timecop.return }

      context 'when expiration_time is nil' do
        let(:expiration_time) { nil }
        let(:expected_expiration_time) { Time.zone.now + validity_length }

        context 'and client_id refers to a short token expiration defined config' do
          let(:access_token_duration) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
          let(:validity_length) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }

          it 'sets expired time to VALIDITY_LENGTH_SHORT_MINUTES from now' do
            expect(subject).to eq(expected_expiration_time)
          end
        end

        context 'and client_id refers to a long token expiration defined config' do
          let(:access_token_duration) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES }
          let(:validity_length) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES }

          it 'sets expired time to VALIDITY_LENGTH_LONG_MINUTES from now' do
            expect(subject).to eq(expected_expiration_time)
          end
        end
      end
    end

    describe '#created_time' do
      subject { access_token.created_time }

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

    describe '#user_attributes' do
      subject { access_token.user_attributes }

      context 'when attributes are present in the ClientConfig access_token_attributes' do
        it 'includes those attributes in the access token' do
          expect(subject['first_name']).to eq(first_name)
          expect(subject['last_name']).to eq(last_name)
          expect(subject['email']).to eq(email)
        end
      end

      context 'when one or more attributes are not present in the ClientConfig access_token_attributes' do
        let(:access_token_attributes) { %w[email] }

        it 'does not include those attributes in the access token' do
          expect(subject['first_name']).to be_nil
          expect(subject['last_name']).to be_nil
          expect(subject['email']).to eq(email)
        end
      end

      context 'when no attributes are present in the ClientConfig access_token_attributes' do
        let(:access_token_attributes) { [] }

        it 'sets an empty hash object in the access token' do
          expect(subject).to eq({})
        end
      end
    end
  end

  describe '#to_s' do
    subject { access_token.to_s }

    let(:expected_hash) do
      {
        uuid: access_token.uuid,
        user_uuid: access_token.user_uuid,
        session_handle: access_token.session_handle,
        client_id: access_token.client_id,
        audience: access_token.audience,
        version: access_token.version,
        last_regeneration_time: access_token.last_regeneration_time.to_i,
        created_time: access_token.created_time.to_i,
        expiration_time: access_token.expiration_time.to_i
      }
    end

    it 'returns a hash of expected values' do
      expect(subject).to eq(expected_hash)
    end
  end
end
