# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::UpdateClaimFromRemoteJob, type: :job do
  let(:user) { create(:user, :loa3) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }
  let(:tracker) { EVSSClaimsSyncStatusTracker.new(user_uuid: user.uuid, claim_id: claim.id) }
  let(:client_stub) { instance_double('EVSS::ClaimsService') }

  subject do
    described_class.new
  end

  describe '#perform' do
    before do
      tracker.set_single_status('REQUESTED')
      expect(Sentry::TagRainbows).to receive(:tag)
      expect(tracker.get_single_status).to eq('REQUESTED')
    end

    it 'overwrites the existing record', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim') do
        expect(User).to receive(:find).with(user.uuid).once.and_return(user)
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to(
          receive(:set_single_status).with(String).and_call_original
        )
        subject.perform(user.uuid, claim.id)
        expect(tracker.get_single_status).to eq('SUCCESS')
      end
    end

    describe 'when error occurs (e.g. timeout)' do
      it 'should set the status to FAILED' do
        allow(client_stub).to receive(:find_claim_by_id).and_raise(
          Common::Exceptions::SentryIgnoredGatewayTimeout
        )
        allow(EVSS::ClaimsService).to receive(:new) { client_stub }
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to(
          receive(:set_single_status).with('FAILED').and_call_original
        )
        subject.perform(user.uuid, claim.id)
        expect(tracker.get_single_status).to eq('FAILED')
      end
    end
  end
end
