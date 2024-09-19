require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe MHV::AccountCreatorJob, type: :job do
  let(:user_account) { create(:user_account, icn:) }
  let(:user_verification) { create(:user_verification, user_account:, user_credential_email:) }
  let(:user_credential_email) { create(:user_credential_email, credential_email: email) }
  let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
  let(:icn) { '10101V964144' }
  let(:email) { 'some-email@email.com' }
  let(:job) { described_class.new }

  before do
    Sidekiq::Testing.inline!
  end

  describe '#perform' do
    context 'when a UserVerification exists' do
      it 'calls the MHV::UserAccount::Creator service class and returns the created MHVUserAccount instance' do
        expect(MHV::UserAccount::Creator).to receive(:new).with(user_verification:).and_call_original
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