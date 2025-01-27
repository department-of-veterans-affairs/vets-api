# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::RetrieveClaimsFromRemoteJob, type: :job do
  subject do
    described_class.new
  end

  let(:user) { create(:user, :loa3) }
  let(:tracker) { EVSSClaimsSyncStatusTracker.new(user_uuid: user.uuid) }
  let(:client_stub) { instance_double(EVSS::ClaimsService) }

  describe '#perform' do
    before do
      tracker.set_collection_status('REQUESTED')
      expect(tracker.get_collection_status).to eq('REQUESTED')
    end

    it 'overwrites the existing record', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      VCR.use_cassette('evss/claims/claims') do
        expect(User).to receive(:find).with(user.uuid).once.and_return(user)
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to receive(:set_collection_status).and_call_original
        subject.perform(user.uuid)
        tracker = EVSSClaimsSyncStatusTracker.find user.uuid
        expect(tracker.get_collection_status).to eq('SUCCESS')
      end
    end

    describe 'when job has failed (e.g. timeout)' do
      it 'sets the status to FAILED' do
        allow(client_stub).to receive(:all_claims).and_raise(
          EVSS::ErrorMiddleware::EVSSBackendServiceError
        )
        allow(EVSS::ClaimsService).to receive(:new) { client_stub }
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to(
          receive(:set_collection_status).with('FAILED').and_call_original
        )
        expect { subject.perform(user.uuid) }.to raise_error(StandardError)
        tracker = EVSSClaimsSyncStatusTracker.find user.uuid
        expect(tracker.get_collection_status).to eq('FAILED')
      end
    end
  end
end
