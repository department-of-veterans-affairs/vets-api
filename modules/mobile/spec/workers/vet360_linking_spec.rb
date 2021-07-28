# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::V0::Vet360LinkingJob, type: :job do
  before { iam_sign_in(FactoryBot.build(:iam_user, :no_vet360_id)) }

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  let(:user) { FactoryBot.build(:iam_user, :no_vet360_id) }

  context 'when linking succeeds' do
    it 'logs the completed transaction id that linked an account with vet360' do
      VCR.use_cassette('profile/init_vet360_id_status_complete') do
        VCR.use_cassette('profile/init_vet360_id_status_incomplete') do
          VCR.use_cassette('profile/init_vet360_id_success') do
            allow(Rails.logger).to receive(:info)
            subject.perform(user.uuid)
            expect(Rails.logger).to have_received(:info).with(
              'Mobile Vet360 account linking succeeded for user with uuid',
              { user_uuid: user.uuid, transaction_id: 'd8951c96-5b8c-42ea-9fbe-e656941b7236' }
            )
          end
        end
      end
    end
  end

  context 'when linking fails' do
    it 'logs the failure with the user uuid' do
      VCR.use_cassette('profile/init_vet360_id_status_400') do
        allow(Rails.logger).to receive(:error)
        expect { subject.perform(user.uuid) }.to raise_error(Common::Exceptions::BackendServiceException)
        expect(Rails.logger).to have_received(:error).with(
          'Mobile Vet360 account linking failed for user with uuid', user_uuid: '3097e489-ad75-5746-ab1a-e0aabc1b426a'
        )
      end
    end
  end
end
