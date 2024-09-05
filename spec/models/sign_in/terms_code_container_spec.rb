# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::TermsCodeContainer, type: :model do
  let(:terms_code_container) { create(:terms_code_container, user_account_uuid:, code:) }

  let(:code) { SecureRandom.hex }
  let(:user_account_uuid) { SecureRandom.uuid }

  describe 'validations' do
    describe '#code' do
      subject { terms_code_container.code }

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
      subject { terms_code_container.user_account_uuid }

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
