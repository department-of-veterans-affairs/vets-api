# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::RefreshToken, type: :model do
  let(:refresh_token) do
    create(:refresh_token,
           user_uuid:,
           uuid:,
           session_handle:,
           anti_csrf_token:,
           nonce:,
           version:)
  end
  let(:user_uuid) { create(:user).uuid }
  let(:uuid) { 'some-uuid' }
  let(:session_handle) { 'some-session-handle' }
  let(:anti_csrf_token) { 'some-anti-csrf-token' }
  let(:nonce) { 'some-nonce' }
  let(:version) { SignIn::Constants::RefreshToken::CURRENT_VERSION }

  describe '#initialize' do
    subject { refresh_token }

    context 'when user_uuid does not exist' do
      let(:user_uuid) { nil }
      let(:expected_error) { ActiveModel::ValidationError }
      let(:expected_error_message) { "Validation failed: User uuid can't be blank" }

      it 'raises a missing user_uuid validation error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when session_handle does not exist' do
      let(:session_handle) { nil }
      let(:expected_error) { ActiveModel::ValidationError }
      let(:expected_error_message) { "Validation failed: Session handle can't be blank" }

      it 'raises a missing session_handle validation error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when anti_csrf_token does not exist' do
      let(:anti_csrf_token) { nil }
      let(:expected_error) { ActiveModel::ValidationError }
      let(:expected_error_message) { "Validation failed: Anti csrf token can't be blank" }

      it 'raises a missing anti_csrf_token validation error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when nil nonce is passed in' do
      let(:nonce) { nil }
      let(:expected_error) { ActiveModel::ValidationError }
      let(:expected_error_message) { "Validation failed: Nonce can't be blank" }

      it 'raises a missing nonce validation error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when nonce param is not defined' do
      let(:refresh_token) do
        SignIn::RefreshToken.new(user_uuid:,
                                 session_handle:,
                                 anti_csrf_token:)
      end
      let(:expected_random_number) { 'some-random-number' }

      before do
        allow(SecureRandom).to receive(:hex).and_return(expected_random_number)
      end

      it 'sets the nonce to a random value' do
        expect(subject.nonce).to eq(expected_random_number)
      end
    end

    context 'when nil uuid is passed in' do
      let(:uuid) { nil }
      let(:expected_error) { ActiveModel::ValidationError }
      let(:expected_error_message) { "Validation failed: Uuid can't be blank" }

      it 'raises a missing uuid validation error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when uuid param is not defined' do
      let(:refresh_token) do
        SignIn::RefreshToken.new(user_uuid:,
                                 session_handle:,
                                 anti_csrf_token:)
      end
      let(:expected_random_number) { 'some-random-number' }

      before do
        allow(SecureRandom).to receive(:hex).and_return(expected_random_number)
      end

      it 'sets the uuid to a random value' do
        expect(subject.nonce).to eq(expected_random_number)
      end
    end

    context 'when nil version is passed in' do
      let(:version) { nil }
      let(:expected_error) { ActiveModel::ValidationError }
      let(:expected_error_message) { "Validation failed: Version can't be blank, Version is not included in the list" }

      it 'raises a missing version validation error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when arbitrary version is passed in' do
      let(:version) { 'banana' }
      let(:expected_error) { ActiveModel::ValidationError }
      let(:expected_error_message) { 'Validation failed: Version is not included in the list' }

      it 'raises a version not included in list validation error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when version param is not defined' do
      let(:refresh_token) do
        SignIn::RefreshToken.new(user_uuid:,
                                 session_handle:,
                                 anti_csrf_token:)
      end
      let(:expected_version) { SignIn::Constants::RefreshToken::CURRENT_VERSION }

      it 'sets the version to the current version' do
        expect(subject.version).to eq(expected_version)
      end
    end

    it 'returns a valid RefreshToken object' do
      expect(subject).to eq(refresh_token)
      expect(subject).to be_valid
    end
  end

  describe '#to_s' do
    subject { refresh_token.to_s }

    let(:expected_hash) do
      {
        uuid: refresh_token.uuid,
        user_uuid: refresh_token.user_uuid,
        session_handle: refresh_token.session_handle,
        version: refresh_token.version
      }
    end

    it 'returns a hash of expected values' do
      expect(subject).to eq(expected_hash)
    end
  end
end
