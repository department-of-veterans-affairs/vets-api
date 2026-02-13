# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::StatePayload, type: :model do
  let(:state_payload) do
    create(:state_payload,
           code_challenge:,
           client_id:,
           type:,
           acr:,
           code:,
           client_state:,
           created_at:,
           scope:,
           operation:)
  end

  let(:code_challenge) { Base64.urlsafe_encode64(SecureRandom.hex) }
  let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }
  let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
  let(:code) { SecureRandom.hex }
  let(:client_config) { create(:client_config) }
  let(:client_id) { client_config.client_id }
  let(:client_state) { SecureRandom.hex }
  let(:created_at) { Time.zone.now.to_i }
  let(:scope) { SignIn::Constants::Auth::DEVICE_SSO }
  let(:operation) { SignIn::Constants::Auth::VERIFY_CTA_AUTHENTICATED }

  describe 'validations' do
    describe '#code' do
      subject { state_payload.code }

      context 'when code is nil' do
        let(:code) { nil }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { "Validation failed: Code can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#type' do
      subject { state_payload.type }

      context 'when type is nil' do
        let(:type) { nil }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Type is not included in the list' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when type is arbitrary' do
        let(:type) { 'some-type' }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Type is not included in the list' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#client_id' do
      subject { state_payload.client_id }

      context 'when client_id is nil' do
        let(:client_id) { nil }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Client id must map to a configuration' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when client_id is an arbitrary value' do
        let(:client_id) { 'some-client-id' }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Client id must map to a configuration' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#acr' do
      subject { state_payload.acr }

      context 'when acr is nil' do
        let(:acr) { nil }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Acr is not included in the list' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when acr is an arbitrary value' do
        let(:acr) { 'some-acr' }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Acr is not included in the list' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#client_state' do
      subject { state_payload.client_state }

      context 'when client_state is shorter than minimum length' do
        let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH - 1) }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Client state is too short (minimum is 22 characters)' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end

  describe '#created_at' do
    subject { state_payload.created_at }

    before { Timecop.freeze }

    after { Timecop.return }

    context 'when created_at is nil' do
      let(:created_at) { nil }
      let(:expected_time) { Time.zone.now.to_i }

      it 'sets created_at to current time' do
        expect(subject).to eq(expected_time)
      end
    end
  end

  describe '#operation' do
    subject { state_payload.operation }

    context 'when operation is not in the allowed list' do
      let(:operation) { 'invalid-operation' }
      let(:expected_error) { ActiveModel::ValidationError }
      let(:expected_error_message) { 'Validation failed: Operation is not included in the list' }

      it 'raises validation error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end
  end
end
