# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeContainer, type: :model do
  let(:code_container) do
    create(:code_container,
           code_challenge:,
           client_id:,
           code:,
           user_verification_id:)
  end

  let(:code_challenge) { Base64.urlsafe_encode64(SecureRandom.hex) }
  let(:code) { SecureRandom.hex }
  let(:client_config) { create(:client_config) }
  let(:client_id) { client_config.client_id }
  let(:user_verification_id) { create(:user_verification).id }

  describe 'validations' do
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

    describe '#user_verification_id' do
      subject { code_container.user_verification_id }

      context 'when user_verification_id is nil' do
        let(:user_verification_id) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#client_id' do
      subject { code_container.client_id }

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
  end
end
