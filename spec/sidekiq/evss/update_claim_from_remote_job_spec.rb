# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::UpdateClaimFromRemoteJob, type: :job do
  subject do
    described_class.new
  end

  let(:user) { create(:user, :loa3) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }
  let(:tracker) { EVSSClaimsSyncStatusTracker.find_or_build(user.uuid) }
  let(:client_stub) { instance_double(EVSS::ClaimsService) }

  describe '#perform' do
    before do
      tracker.claim_id = claim.id
      tracker.set_single_status('REQUESTED')
      expect(tracker.get_single_status).to eq('REQUESTED')
    end

    it 'overwrites the existing record', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim_with_docs') do
        expect(User).to receive(:find).with(user.uuid).once.and_return(user)
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to(
          receive(:set_single_status).with(String).and_call_original
        )
        subject.perform(user.uuid, claim.id)
        tracker = EVSSClaimsSyncStatusTracker.find(user.uuid)
        tracker.claim_id = claim.id
        expect(tracker.get_single_status).to eq('SUCCESS')
      end
    end

    context 'when a standard error occurs' do
      it 'sets the status to FAILED', :aggregate_failures do
        allow(client_stub).to receive(:find_claim_with_docs_by_id).and_raise(
          EVSS::ErrorMiddleware::EVSSBackendServiceError
        )
        allow(EVSS::ClaimsService).to receive(:new) { client_stub }
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to(
          receive(:set_single_status).with('FAILED').and_call_original
        )
        expect { subject.perform(user.uuid, claim.id) }.to raise_error(StandardError)
        tracker = EVSSClaimsSyncStatusTracker.find(user.uuid)
        tracker.claim_id = claim.id
        expect(tracker.get_single_status).to eq('FAILED')
      end
    end

    context 'when an active record error occurs' do
      it 'sets the status to FAILED', :aggregate_failures do
        expect(User).to receive(:find).with(user.uuid).once.and_return(user)
        allow(EVSSClaim).to receive(:find).and_raise(ActiveRecord::ConnectionTimeoutError)
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to(
          receive(:set_single_status).with(String).and_call_original
        )
        expect { subject.perform(user.uuid, claim.id) }.to raise_error(ActiveRecord::ConnectionTimeoutError)
        tracker = EVSSClaimsSyncStatusTracker.find(user.uuid)
        tracker.claim_id = claim.id
        expect(tracker.get_single_status).to eq('FAILED')
      end
    end
  end
end
