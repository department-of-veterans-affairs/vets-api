# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::SessionContainer, type: :model do
  let(:session_container) do
    create(:session_container,
           session:,
           refresh_token:,
           access_token:,
           anti_csrf_token:,
           client_config:)
  end

  let(:session) { create(:oauth_session) }
  let(:refresh_token) { create(:refresh_token) }
  let(:access_token) { create(:access_token) }
  let(:anti_csrf_token) { SecureRandom.hex }
  let(:client_config) { create(:client_config) }

  describe 'validations' do
    describe '#session' do
      subject { session_container.session }

      context 'when session is nil' do
        let(:session) { nil }
        let(:expected_error_message) { "Validation failed: Session can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#refresh_token' do
      subject { session_container.refresh_token }

      context 'when refresh_token is nil' do
        let(:refresh_token) { nil }
        let(:expected_error_message) { "Validation failed: Refresh token can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#access_token' do
      subject { session_container.access_token }

      context 'when access_token is nil' do
        let(:access_token) { nil }
        let(:expected_error_message) { "Validation failed: Access token can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#anti_csrf_token' do
      subject { session_container.anti_csrf_token }

      context 'when anti_csrf_token is nil' do
        let(:anti_csrf_token) { nil }
        let(:expected_error_message) { "Validation failed: Anti csrf token can't be blank" }
        let(:expected_error) { ActiveModel::ValidationError }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#client_config' do
      subject { session_container.client_config }

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
