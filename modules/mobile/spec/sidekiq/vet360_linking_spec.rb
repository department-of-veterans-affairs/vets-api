# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe Mobile::V0::Vet360LinkingJob, type: :job do
  let(:user) { create(:user, :loa3) }

  context 'when linking request is successfully made' do
    it 'logs the user id, transaction id, and creates a mobile user that linked an account with vet360' do
      VCR.use_cassette('mobile/profile/init_vet360_id_success') do
        expect(Rails.logger).to receive(:info).with(
          'Mobile Vet360 account linking request succeeded for user with uuid',
          { user_uuid: user.uuid, transaction_id: 'd8951c96-5b8c-42ea-9fbe-e656941b7236' }
        )
        subject.perform(user.uuid)
        expect(Mobile::User.where(icn: user.icn)).to exist
      end
    end

    it 'increments mobile user vet360 linked attempts' do
      Mobile::User.create(icn: user.icn, vet360_link_attempts: 1)

      VCR.use_cassette('mobile/profile/init_vet360_id_success') do
        subject.perform(user.uuid)
        expect(Mobile::User.where(icn: user.icn, vet360_link_attempts: 2)).to exist
      end
    end

    it 'flips vet360_linked to false if mobile user previously was linked' do
      Mobile::User.create(icn: user.icn, vet360_link_attempts: 1, vet360_linked: true)

      VCR.use_cassette('mobile/profile/init_vet360_id_success') do
        subject.perform(user.uuid)
        expect(Mobile::User.where(icn: user.icn, vet360_link_attempts: 2, vet360_linked: false)).to exist
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
