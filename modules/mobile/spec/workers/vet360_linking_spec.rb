# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe Mobile::V0::Vet360LinkingJob, type: :job do
  let(:user) { create(:user, :loa3) }

  context 'when linking succeeds' do
    it 'logs the completed transaction id that linked an account with vet360' do
      VCR.use_cassette('mobile/profile/init_vet360_id_status_complete') do
        VCR.use_cassette('mobile/profile/init_vet360_id_success') do
          allow(Rails.logger).to receive(:info).with(
            'mobile syncronous profile update complete',
            { transaction_id: 'd8951c96-5b8c-42ea-9fbe-e656941b7236' }
          )
          expect(Rails.logger).to receive(:info).with(
            'Mobile Vet360 account linking succeeded for user with uuid',
            { user_uuid: user.uuid, transaction_id: 'd8951c96-5b8c-42ea-9fbe-e656941b7236' }
          )
          subject.perform(user.uuid)
        end
      end
    end
  end

  context 'when linking fails' do
    it 'logs the failure with the user uuid' do
      VCR.use_cassette('mobile/profile/init_vet360_id_status_400') do
        expect(Rails.logger).to receive(:error).with(
          'Mobile Vet360 account linking failed for user with uuid', { user_uuid: user.uuid }
        )
        expect { subject.perform(user.uuid) }.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end

  context 'with IAM user' do
    let(:user) { FactoryBot.build(:iam_user, :no_vet360_id) }

    before { iam_sign_in(FactoryBot.build(:iam_user, :no_vet360_id)) }

    it 'works as expected' do
      VCR.use_cassette('mobile/profile/init_vet360_id_status_complete') do
        VCR.use_cassette('mobile/profile/init_vet360_id_success') do
          allow(Rails.logger).to receive(:info).with(
            'mobile syncronous profile update complete',
            { transaction_id: 'd8951c96-5b8c-42ea-9fbe-e656941b7236' }
          )
          expect(Rails.logger).to receive(:info).with(
            'Mobile Vet360 account linking succeeded for user with uuid',
            { user_uuid: user.uuid, transaction_id: 'd8951c96-5b8c-42ea-9fbe-e656941b7236' }
          )
          subject.perform(user.uuid)
        end
      end
    end
  end

  context 'when user is not found' do
    it 'caches the expected claims and appeals' do
      expect do
        subject.perform('iamtheuuidnow')
      end.to raise_error(described_class::MissingUserError, 'iamtheuuidnow')
    end
  end
end
