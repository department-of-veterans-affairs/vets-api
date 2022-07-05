# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CredentialInfo, type: :model do
  let(:credential_info) do
    create(:credential_info, id_token: id_token, csp_uuid: csp_uuid, credential_type: credential_type)
  end

  let(:id_token) { SecureRandom.hex }
  let(:csp_uuid) { SecureRandom.uuid }
  let(:credential_type) { SignIn::Constants::Auth::REDIRECT_URLS.first }

  describe 'validations' do
    describe '#id_token' do
      subject { credential_info.id_token }

      context 'when id_token is nil' do
        let(:id_token) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#csp_uuid' do
      subject { credential_info.csp_uuid }

      context 'when csp_uuid is nil' do
        let(:csp_uuid) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#credential_type' do
      subject { credential_info.credential_type }

      context 'when credential_type is an arbitrary value' do
        let(:credential_type) { 'some-credential-type' }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
