# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeChallengeStateMap, type: :model do
  let(:code_challenge_state_map) do
    create(:code_challenge_state_map, code_challenge: code_challenge, state: state)
  end

  let(:code_challenge) { Base64.urlsafe_encode64(SecureRandom.hex) }
  let(:state) { SecureRandom.hex }

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
  end
end
