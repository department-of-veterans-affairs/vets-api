# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeContainer, type: :model do
  let(:code_container) do
    create(:code_container, code_challenge: code_challenge, code: code, user_account_uuid: user_account_uuid)
  end

  let(:code_challenge) { Base64.urlsafe_encode64(SecureRandom.hex) }
  let(:code) { SecureRandom.hex }
  let(:user_account_uuid) { create(:user_account).id }

  describe 'validations' do
    describe '#code_challenge' do
      subject { code_container.code_challenge }

      context 'when code_challenge is nil' do
        let(:code_challenge) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#code' do
      subject { code_container.code }

      context 'when code is nil' do
        let(:code) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#user_account_uuid' do
      subject { code_container.user_account_uuid }

      context 'when user_account_uuid is nil' do
        let(:user_account_uuid) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
