# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CredentialLevel, type: :model do
  let(:credential_level) do
    create(:credential_level,
           requested_acr: requested_acr,
           current_ial: current_ial,
           max_ial: max_ial,
           credential_type: credential_type)
  end

  let(:requested_acr) { SignIn::Constants::Auth::ACR_VALUES.first }
  let(:current_ial) { SignIn::Constants::Auth::IAL_ONE }
  let(:max_ial) { SignIn::Constants::Auth::IAL_ONE }
  let(:credential_type) { SignIn::Constants::Auth::CSP_TYPES.first }

  describe 'validations' do
    describe '#requested_acr' do
      subject { credential_level.requested_acr }

      context 'when requested_acr is an arbitrary value' do
        let(:requested_acr) { 'some-requested-acr' }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Requested acr is not included in the list' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#credential_type' do
      subject { credential_level.credential_type }

      context 'when credential_type is an arbitrary value' do
        let(:credential_type) { 'some-credential-type' }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Credential type is not included in the list' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#current_ial' do
      subject { credential_level.current_ial }

      context 'when current_ial is an arbitrary value' do
        let(:current_ial) { 'some-current-ial' }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Current ial is not included in the list' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#max_ial' do
      subject { credential_level.max_ial }

      context 'when max_ial is an arbitrary value' do
        let(:max_ial) { 'some-max-ial' }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) do
          'Validation failed: Max ial is not included in the list, Max ial cannot be less than Current ial'
        end

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when max_ial is less than current_ial' do
        let(:max_ial) { SignIn::Constants::Auth::IAL_ONE }
        let(:current_ial) { SignIn::Constants::Auth::IAL_TWO }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { 'Validation failed: Max ial cannot be less than Current ial' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end

  describe '#can_uplevel_credential?' do
    subject { credential_level.can_uplevel_credential? }

    context 'when requested acr is min' do
      let(:requested_acr) { SignIn::Constants::Auth::MIN }

      context 'and current_ial is less than max_ial' do
        let(:current_ial) { SignIn::Constants::Auth::IAL_ONE }
        let(:max_ial) { SignIn::Constants::Auth::IAL_TWO }

        it 'returns true' do
          expect(subject).to be(true)
        end
      end

      context 'and current_ial is equal to max_ial' do
        let(:current_ial) { SignIn::Constants::Auth::IAL_ONE }
        let(:max_ial) { SignIn::Constants::Auth::IAL_ONE }

        it 'returns false' do
          expect(subject).to be(false)
        end
      end
    end

    context 'when requested acr is some other value' do
      let(:requested_acr) { SignIn::Constants::Auth::ACR_VALUES.first }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end
end
