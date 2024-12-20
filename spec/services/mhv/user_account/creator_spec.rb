# frozen_string_literal: true

require 'rails_helper'
require 'mhv/account_creation/service'

RSpec.describe MHV::UserAccount::Creator do
  subject { described_class.new(user_verification:, break_cache:) }

  let(:user_account) { create(:user_account, icn:) }
  let(:user_verification) { create(:user_verification, user_account:, user_credential_email:) }
  let(:user_credential_email) { create(:user_credential_email, credential_email: email) }
  let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
  let(:icn) { '10101V964144' }
  let(:email) { 'some-email@email.com' }
  let(:tou_occurred_at) { terms_of_use_agreement&.created_at }
  let(:break_cache) { false }
  let(:mhv_client) { instance_double(MHV::AccountCreation::Service) }
  let(:mhv_response_body) do
    {
      user_profile_id: '12345678',
      premium: true,
      champ_va: true,
      patient: true,
      sm_account_created: true
    }
  end

  before do
    allow(Rails.logger).to receive(:error)

    allow(MHV::AccountCreation::Service).to receive(:new).and_return(mhv_client)
    allow(mhv_client).to receive(:create_account)
      .with(icn:, email:, tou_occurred_at:, break_cache:)
      .and_return(mhv_response_body)
  end

  describe '#perform' do
    shared_examples 'an invalid creator' do
      let(:expected_log_payload) { { error_message: /#{expected_error_message}/, icn: } }
      let(:expected_log_message) { '[MHV][UserAccount][Creator] validation error' }

      it 'logs and raises an error' do
        expect { subject.perform }.to raise_error(MHV::UserAccount::Errors::ValidationError)
        expect(Rails.logger).to have_received(:error).with(expected_log_message,
                                                           expected_log_payload)
      end
    end

    describe 'validations' do
      context 'when icn is not present' do
        let(:icn) { nil }
        let(:expected_error_message) { 'ICN must be present' }

        it_behaves_like 'an invalid creator'
      end

      context 'when email is not present' do
        let(:user_credential_email) { nil }
        let(:expected_error_message) { 'Email must be present' }

        it_behaves_like 'an invalid creator'
      end
    end

    context 'when tou_occurred_at is not present' do
      let(:terms_of_use_agreement) { nil }
      let(:expected_error_message) { 'Current terms of use agreement must be present' }

      it_behaves_like 'an invalid creator'
    end

    context 'when current_tou_agreement is not accepted' do
      let(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response: :declined) }
      let(:expected_error_message) { "Current terms of use agreement must be 'accepted'" }

      it_behaves_like 'an invalid creator'
    end

    context 'when icn, email, tou_occurred_at, tou accepted are valid' do
      context 'when break_cache is false' do
        it 'calls MHV::AccountCreation::Service#create_account with break_cache: false' do
          subject.perform
          expect(mhv_client).to have_received(:create_account).with(icn:, email:, tou_occurred_at:, break_cache: false)
        end
      end

      context 'when break_cache is true' do
        let(:break_cache) { true }

        it 'calls MHV::AccountCreation::Service#create_account with break_cache: true' do
          subject.perform
          expect(mhv_client).to have_received(:create_account).with(icn:, email:, tou_occurred_at:, break_cache: true)
        end
      end
    end
  end

  context 'when the mhv response is successful' do
    context 'when the MHVUserAccount is valid' do
      it 'retuns a MHVUserAccount' do
        mhv_user_account = subject.perform
        expect(mhv_user_account).to be_a(MHVUserAccount)
        expect(mhv_user_account).to be_valid
      end
    end

    context 'when the MHVUserAccount is invalid' do
      let(:mhv_response_body) do
        {
          user_profile_id: nil,
          premium: true,
          champ_va: true,
          patient: true,
          sm_account_created: true
        }
      end

      let(:expected_log_message) { '[MHV][UserAccount][Creator] validation error' }
      let(:expected_log_payload) do
        {
          error_message: 'Validation failed: User profile can\'t be blank',
          icn:
        }
      end

      it 'logs and raises an error' do
        expect { subject.perform }.to raise_error(MHV::UserAccount::Errors::ValidationError)
        expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
      end
    end
  end

  context 'when the mhv response is not successful' do
    let(:expected_log_message) { '[MHV][UserAccount][Creator] client error' }
    let(:expected_log_payload) do
      {
        error_message: 'error',
        icn:
      }
    end

    before do
      allow(mhv_client).to receive(:create_account).and_raise(Common::Client::Errors::ClientError, 'error')
    end

    it 'logs and raises an error' do
      expect { subject.perform }.to raise_error(MHV::UserAccount::Errors::MHVClientError)
      expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
    end
  end

  context 'when an unexpected error occurs' do
    let(:expected_log_message) { '[MHV][UserAccount][Creator] creator error' }
    let(:expected_log_payload) do
      {
        error_message: 'error',
        icn:
      }
    end

    before do
      allow(mhv_client).to receive(:create_account).and_raise(StandardError, 'error')
    end

    it 'logs and raises an error' do
      expect { subject.perform }.to raise_error(MHV::UserAccount::Errors::CreatorError)
      expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
    end
  end
end
