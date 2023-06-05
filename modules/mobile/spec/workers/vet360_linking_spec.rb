# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe Mobile::V0::Vet360LinkingJob, type: :job do
  let(:user) { create(:user, :loa3) }

  context 'when linking request is successfully made' do
    it 'logs the user id and transaction id that linked an account with vet360' do
      VCR.use_cassette('mobile/profile/init_vet360_id_success') do
        expect(Rails.logger).to receive(:info).with(
          'Mobile Vet360 account linking request succeeded for user with uuid',
          { user_uuid: user.uuid, transaction_id: 'd8951c96-5b8c-42ea-9fbe-e656941b7236' }
        )
        subject.perform(user.uuid)
      end
    end
  end

  context 'when linking request fails' do
    it 'logs the user uuid and error message and raises an error' do
      VCR.use_cassette('mobile/profile/init_vet360_id_status_400') do
        expect(Rails.logger).to receive(:error).with(
          'Mobile Vet360 account linking request failed for user with uuid',
          {
            user_uuid: user.uuid,
            message: 'BackendServiceException: {:source=>"VAProfile::Person::Service", :code=>"VET360_PERS101"}'
          }
        )
        expect do
          subject.perform(user.uuid)
        end.to raise_error(Common::Exceptions::BackendServiceException)
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
