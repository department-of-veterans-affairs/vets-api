# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeChallengeStateMap, type: :model do
  let(:code_challenge_state_map) do
    create(:code_challenge_state_map,
           code_challenge: code_challenge,
           client_id: client_id,
           state: state,
           client_state: client_state)
  end

  let(:code_challenge) { Base64.urlsafe_encode64(SecureRandom.hex) }
  let(:state) { SecureRandom.hex }
  let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }
  let(:client_state) { SecureRandom.hex }

  describe 'validations' do
    describe '#code_challenge' do
      subject { code_challenge_state_map.code_challenge }

      context 'when code_challenge is nil' do
        let(:code_challenge) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#state' do
      subject { code_challenge_state_map.state }

      context 'when state is nil' do
        let(:state) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#client_id' do
      subject { code_challenge_state_map.client_id }

      context 'when client_id is nil' do
        let(:client_id) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when client_id is an arbitrary value' do
        let(:client_id) { 'some-client-id' }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#client_state' do
      subject { code_challenge_state_map.client_state }

      context 'when client_state is shorter than minimum length' do
        let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH - 1) }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
