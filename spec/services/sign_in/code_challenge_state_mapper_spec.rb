# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeChallengeStateMapper do
  describe '#perform' do
    subject do
      SignIn::CodeChallengeStateMapper.new(code_challenge: code_challenge,
                                           code_challenge_method: code_challenge_method,
                                           client_state: client_state,
                                           client_id: client_id).perform
    end

    let(:code_challenge) { 'some-code-challenge' }
    let(:code_challenge_method) { 'some-code-challenge-method' }
    let(:client_state) { 'some-client-state' }
    let(:client_id) { 'some-client-id' }
    let(:client_state_minimum_length) { SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }

    context 'when code_challenge_method does not equal accepted method' do
      let(:code_challenge_method) { 'some-arbitrary-code-challenge-method' }
      let(:expected_error) { SignIn::Errors::CodeChallengeMethodMismatchError }
      let(:expected_error_message) { 'Code Challenge Method is not valid' }

      it 'raises a code challenge method mismatch error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when code_challenge_method equals accepted method' do
      let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }

      context 'and code_challenge is not properly URL encoded' do
        let(:code_challenge) { '///some-not-url-safe code-challenge///' }
        let(:expected_error) { SignIn::Errors::CodeChallengeMalformedError }
        let(:expected_error_message) { 'Code Challenge is not valid' }

        it 'raises a code challenge method mismatch error' do
          expect { subject }.to raise_exception(expected_error, expected_error_message)
        end
      end

      context 'and code_challenge is properly URL encoded' do
        let(:code_challenge) { Base64.urlsafe_encode64('some-safe-code-challenge') }
        let(:code_challenge_remove_base64_padding) do
          Base64.urlsafe_encode64(Base64.urlsafe_decode64(code_challenge.to_s), padding: false)
        end
        let(:state) { 'some-state-value' }
        let(:client_id) { SignIn::Constants::Auth::CLIENT_IDS.first }
        let(:client_state) { SecureRandom.alphanumeric(client_state_minimum_length + 1) }

        before do
          allow(SecureRandom).to receive(:hex).and_return(state)
        end

        shared_context 'properly mapped code challenge state' do
          it 'returns a state value' do
            expect(subject).to eq(state)
          end

          it 'creates a CodeChallengeStateMap object that maps code_challenge and state' do
            state = subject
            code_challenge_state_map = SignIn::CodeChallengeStateMap.find(state)
            expect(code_challenge_state_map.code_challenge).to eq(code_challenge_remove_base64_padding)
            expect(code_challenge_state_map.client_state).to eq(client_state)
          end
        end

        context 'and given client_id is not within accepted client ids list' do
          let(:client_id) { 'some-arbitrary-client-id' }
          let(:expected_error) { SignIn::Errors::CodeChallengeStateMapError }
          let(:expected_error_message) { 'Code Challenge or State or Client id is not valid' }

          it 'raises a code challenge state map error' do
            expect { subject }.to raise_exception(expected_error, expected_error_message)
          end
        end

        context 'and given client_id is within accepted client ids list' do
          let(:client_id) { SignIn::Constants::Auth::CLIENT_IDS.first }

          it_behaves_like 'properly mapped code challenge state'
        end

        context 'and given client_state is nil' do
          let(:client_state) { nil }

          it_behaves_like 'properly mapped code challenge state'
        end

        context 'and given client_state is less than minimum client state length' do
          let(:client_state) { SecureRandom.alphanumeric(client_state_minimum_length - 1) }
          let(:expected_error) { SignIn::Errors::CodeChallengeStateMapError }
          let(:expected_error_message) { 'Code Challenge or State or Client id is not valid' }

          it 'raises a code challenge state map error' do
            expect { subject }.to raise_exception(expected_error, expected_error_message)
          end
        end

        context 'and given client_state is greater than minimum client state length' do
          let(:client_state) { SecureRandom.alphanumeric(client_state_minimum_length + 1) }

          it_behaves_like 'properly mapped code challenge state'
        end
      end
    end
  end
end
