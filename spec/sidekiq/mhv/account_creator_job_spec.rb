# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe MHV::AccountCreatorJob, type: :job do
  let(:user_account) { create(:user_account, icn:) }
  let(:user_verification) { create(:user_verification, user_account:, user_credential_email:) }
  let(:user_credential_email) { create(:user_credential_email, credential_email: email) }
  let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
  let(:icn) { '10101V964144' }
  let(:email) { 'some-email@email.com' }
  let(:mhv_client) { instance_double(MHV::AccountCreation::Service) }
  let(:job) { described_class.new }
  let(:break_cache) { true }
  let(:mhv_response_body) do
    {
      user_profile_id: '12345678',
      premium: true,
      champ_va: true,
      patient: true,
      sm_account_created: true
    }
  end

  it 'is unique for 5 minutes' do
    expect(described_class.sidekiq_options['unique_for']).to eq(5.minutes)
  end

  describe '#perform' do
    before do
      allow(MHV::AccountCreation::Service).to receive(:new).and_return(mhv_client)
      allow(mhv_client).to receive(:create_account).and_return(mhv_response_body)
    end

    Sidekiq::Testing.inline! do
      context 'when a UserVerification exists' do
        it 'calls the MHV::UserAccount::Creator service class and returns the created MHVUserAccount instance' do
          expect(MHV::UserAccount::Creator).to receive(:new).with(user_verification:, break_cache:).and_call_original
          job.perform(user_verification.id)
        end

        context 'when the MHV API call is successful' do
          it 'creates & returns a new MHVUserAccount instance' do
            response = job.perform(user_verification.id)
            expect(response).to be_an_instance_of(MHVUserAccount)
          end
        end
      end

      context 'when a UserVerification does not exist' do
        let(:expected_error_id) { 999 }
        let(:expected_error_message) do
          "MHV AccountCreatorJob failed: UserVerification not found for id #{expected_error_id}"
        end

        it 'logs an error' do
          expect(Rails.logger).to receive(:error).with(expected_error_message)
          job.perform(expected_error_id)
        end
      end
    end
  end
end
