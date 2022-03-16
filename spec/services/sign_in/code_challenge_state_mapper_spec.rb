# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeChallengeStateMapper do
  describe '#perform' do
    subject do
      SignIn::CodeChallengeStateMapper.new(code_challenge: code_challenge,
                                           code_challenge_method: code_challenge_method).perform
    end

    let(:code_challenge) { 'some-code-challenge' }
    let(:code_challenge_method) { 'some-code-challenge-method' }

    context 'when code_challenge_method does not equal accepted method' do
      let(:code_challenge_method) { 'some-arbitrary-code-challenge-method' }
      let(:expected_error) { SignIn::Errors::CodeChallengeMethodMismatchError }

      it 'raises a code challenge method mismatch error' do
        expect { subject }.to raise_exception(expected_error)
      end
    end

    context 'when code_challenge_method equals accepted method' do
      let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }

      context 'and code_challenge is not properly URL encoded' do
        let(:code_challenge) { '///some-not-url-safe code-challenge///' }
        let(:expected_error) { SignIn::Errors::CodeChallengeMalformedError }

        it 'raises a code challenge method mismatch error' do
          expect { subject }.to raise_exception(expected_error)
        end
      end

      context 'and code_challenge is properly URL encoded' do
        let(:code_challenge) { Base64.urlsafe_encode64('some-safe-code-challenge') }
        let(:code_challenge_remove_base64_padding) do
          Base64.urlsafe_encode64(Base64.urlsafe_decode64(code_challenge.to_s), padding: false)
        end
        let(:state) { 'some-state-value' }

        before do
          allow(SecureRandom).to receive(:hex).and_return(state)
        end

        it 'returns a state value' do
          expect(subject).to eq(state)
        end

        it 'creates a CodeChallengeStateMap object that maps code_challenge and state' do
          state = subject
          code_challenge_state_map = SignIn::CodeChallengeStateMap.find(state)
          expect(code_challenge_state_map.code_challenge).to eq(code_challenge_remove_base64_padding)
        end
      end
    end
  end
end
