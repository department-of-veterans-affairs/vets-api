# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountConfig, type: :model do
  let(:certificates) { [] }
  let(:service_account_id) { SecureRandom.hex }
  let(:access_token_duration) { SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
  let(:description) { 'some-description' }
  let(:access_token_audience) { 'some-access-token-audience' }
  let(:access_token_user_attributes) { [] }
  let(:service_account_config) do
    create(:service_account_config,
           service_account_id:,
           access_token_duration:,
           description:,
           access_token_audience:,
           access_token_user_attributes:,
           certificates:)
  end

  describe 'associations' do
    it { is_expected.to have_many(:config_certificates).dependent(:destroy) }
    it { is_expected.to have_many(:certs).through(:config_certificates).class_name('SignIn::Certificate') }
  end

  describe 'concerns' do
    subject { service_account_config }

    it_behaves_like 'implements certifiable concern'
  end

  describe 'validations' do
    let(:expected_error) { ActiveRecord::RecordInvalid }

    describe '#service_account_id' do
      subject { service_account_config.service_account_id }

      context 'when service_account_id is nil' do
        let(:service_account_id) { nil }
        let(:expected_error_message) { "Validation failed: Service account can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when service_account_id is not unique' do
        let!(:old_service_account_config) { create(:service_account_config) }
        let(:service_account_id) { old_service_account_config.service_account_id }
        let(:expected_error_message) { 'Validation failed: Service account has already been taken' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#description' do
      subject { service_account_config.description }

      context 'when description is nil' do
        let(:description) { nil }
        let(:expected_error_message) { "Validation failed: Description can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#access_token_audience' do
      subject { service_account_config.access_token_audience }

      context 'when access_token_audience is empty' do
        let(:access_token_audience) { nil }
        let(:expected_error_message) { "Validation failed: Access token audience can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#access_token_duration' do
      subject { service_account_config.access_token_duration }

      let(:validity_length) { SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES }

      context 'when access_token_duration is empty' do
        let(:access_token_duration) { nil }
        let(:expected_error_message) do
          "Validation failed: Access token duration can't be blank, Access token duration is not included in the list"
        end

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when access_token_duration is an arbitrary interval' do
        let(:access_token_duration) { 300.days }
        let(:expected_error_message) { 'Validation failed: Access token duration is not included in the list' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#access_token_user_attributes' do
      subject { service_account_config.access_token_user_attributes }

      let(:expected_error_message) do
        'Validation failed: Access token user attributes is not included in the list'
      end

      context 'when access_token_user_attributes is empty' do
        it 'does not raise validation error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when access_token_user_attributes contains an unallowed item' do
        let(:access_token_user_attributes) { ['foo'] }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when access_token_user_attributes contains an allowed item' do
        let(:access_token_user_attributes) { items }

        context 'and it contains only allowed items' do
          let(:items) { ['icn'] }

          it 'does not raise validation error' do
            expect { subject }.not_to raise_error
          end
        end

        context 'and it also contains an unallowed item' do
          let(:items) { %w[icn foo] }

          it 'raises validation error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end
    end
  end
end
