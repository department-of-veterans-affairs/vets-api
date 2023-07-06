# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountConfig, type: :model do
  let(:certificate_path) { 'spec/fixtures/sign_in/sample_service_account_public.pem' }
  let(:second_certificate_path) { 'spec/fixtures/sign_in/sample_service_account_public_2.pem' }
  let(:service_account_assertion_certificate) { [File.read(certificate_path)] }
  let(:second_service_account_assertion_certificate) { [File.read(second_certificate_path)] }
  let(:service_account_id) { SecureRandom.hex }
  let(:service_account_config_params) { { service_account_id: } }
  let(:service_account_config) do
    create(:service_account_config,
           service_account_config_params.merge({ certificates: service_account_assertion_certificate }))
  end

  describe 'validations' do
    let(:expected_error) { ActiveRecord::RecordInvalid }

    shared_examples 'missing_attribute_error' do
      it 'raises validation error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    describe '#service_account_id' do
      subject { service_account_config.service_account_id }

      context 'when service_account_id is nil' do
        let(:service_account_id) { nil }
        let(:expected_error_message) { "Validation failed: Service account can't be blank" }

        it_behaves_like 'missing_attribute_error'
      end

      context 'when service_account_id is a duplicate' do
        let(:second_service_account_config) do
          create(:service_account_config,
                 service_account_config_params.merge({ certificates: second_service_account_assertion_certificate }))
        end
        let(:expected_error_message) { 'Validation failed: Service account has already been taken' }

        it 'raises an id taken error' do
          expect(service_account_config).to be_valid
          expect { second_service_account_config }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when service_account_id is not a duplicate' do
        let(:second_service_account_config) do
          create(:service_account_config,
                 { service_account_id: SecureRandom.hex, certificates: second_service_account_assertion_certificate })
        end

        it 'creates the Service Account' do
          expect(subject).not_to eq(second_service_account_config.service_account_id)
          expect(second_service_account_config).to be_valid
        end
      end
    end

    describe '#description' do
      subject { service_account_config.description }

      let(:service_account_config_params) { { service_account_id:, description: } }

      context 'when description is nil' do
        let(:description) { nil }
        let(:expected_error_message) { "Validation failed: Description can't be blank" }

        it_behaves_like 'missing_attribute_error'
      end
    end

    describe '#scopes' do
      subject { service_account_config.scopes }

      let(:service_account_config_params) { { service_account_id:, scopes: } }

      context 'when scopes is empty' do
        let(:scopes) { [] }
        let(:expected_error_message) { "Validation failed: Scopes can't be blank" }

        it_behaves_like 'missing_attribute_error'
      end
    end

    describe '#access_token_audience' do
      subject { service_account_config.access_token_audience }

      let(:service_account_config_params) { { service_account_id:, access_token_audience: } }

      context 'when access_token_audience is empty' do
        let(:access_token_audience) { nil }
        let(:expected_error_message) { "Validation failed: Access token audience can't be blank" }

        it_behaves_like 'missing_attribute_error'
      end
    end

    describe '#access_token_duration' do
      subject { service_account_config.access_token_duration }

      let(:validity_length) { SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
      let(:service_account_config_params) { { service_account_id:, access_token_duration: } }

      context 'when access_token_duration is empty' do
        let(:access_token_duration) { nil }
        let(:expected_error_message) { "Validation failed: Access token duration can't be blank" }

        it_behaves_like 'missing_attribute_error'
      end

      context 'when access_token_duration is greater than 5 minutes' do
        let(:access_token_duration) { 10.minutes }
        let(:expected_error_message) do
          "Validation failed: Access token duration must be <= #{validity_length.in_minutes} minutes"
        end

        it 'does something' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
