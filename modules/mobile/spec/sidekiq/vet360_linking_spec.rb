# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::Vet360LinkingJob, type: :job do
  let(:user) { create(:user, :loa3) }

  context 'when linking request is successfully made' do
    it 'logs the user id and transaction id of successful linking request' do
      VCR.use_cassette('mobile/profile/v2/init_vet360_id_success') do
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
      VCR.use_cassette('mobile/profile/v2/init_vet360_id_status_400') do
        expect(Rails.logger).to receive(:error).with(
          'Mobile Vet360 account linking request failed for user with uuid',
          {
            user_uuid: user.uuid,
            message: 'BackendServiceException: {:source=>"VAProfile::Person::Service", :code=>"VET360_PERS101"}'
          }
        )
        subject.perform(user.uuid)
      end
    end
  end

  context 'when user is not found' do
    it 'logs the user uuid and error message' do
      expect(Rails.logger).to receive(:error).with('Mobile Vet360 account linking request failed for user with uuid',
                                                   { user_uuid: 'iamtheuuidnow', message: 'iamtheuuidnow' })
      subject.perform('iamtheuuidnow')
    end
  end
end
