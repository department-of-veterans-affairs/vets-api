# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ValidatedCredential, type: :model do
  let(:validated_credential) do
    create(:validated_credential,
           user_verification:,
           credential_email:,
           client_config:,
           user_attributes:,
           device_sso:)
  end

  let(:user_verification) { create(:user_verification) }
  let(:credential_email) { 'some-credential-email' }
  let(:client_config) { create(:client_config) }
  let(:user_attributes) do
    { first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      email: Faker::Internet.email }
  end
  let(:device_sso) { false }

  describe 'validations' do
    describe '#user_verification' do
      subject { validated_credential.user_verification }

      context 'when user_verification is nil' do
        let(:user_verification) { nil }
        let(:expected_error_message) { "Validation failed: User verification can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when client_config is nil' do
        let(:client_config) { nil }
        let(:expected_error_message) { "Validation failed: Client config can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
