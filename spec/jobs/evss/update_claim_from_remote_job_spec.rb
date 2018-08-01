# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::UpdateClaimFromRemoteJob, type: :job do
  let(:user) { create(:user, :loa3) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }
  let(:tracker) { EVSSClaimsSyncStatusTracker.new(user_uuid: user.uuid, claim_id: claim.id) }

  describe '#perform' do
    before do
      tracker.set_single_status('REQUESTED')
      expect(Sentry::TagRainbows).to receive(:tag)
      expect(tracker.get_single_status.response[:status]).to eq('REQUESTED')
    end

    subject do
      described_class.new
    end

    it 'overwrites the existing record', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim') do
        expect(User).to receive(:find).with(user.uuid).once.and_return(user)
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to(
          receive(:set_single_status).with(String).and_call_original
        )
        subject.perform(user.uuid, claim.id)
        expect(tracker.get_single_status.response[:status]).to eq('SUCCESS')
      end
    end

    describe 'when job has failed' do
      it 'should set the status to FAILED' do
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to(
          receive(:set_single_status).with('FAILED').and_call_original
        )
        subject.sidekiq_retries_exhausted_block.call('args' => [user.uuid, claim.id])
        expect(tracker.get_single_status.response[:status]).to eq('FAILED')
      end
    end
  end
end
