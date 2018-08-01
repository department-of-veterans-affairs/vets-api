# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::UpdateClaimFromRemoteJob, type: :job do
  let(:user) { create(:user, :loa3) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }
  let(:cacher) { EVSSClaimsRedisHelper.new(user_uuid: user.uuid, claim_id: claim.id) }

  describe '#perform' do
    before do
      cacher.cache_one(status: 'REQUESTED')
      expect(Sentry::TagRainbows).to receive(:tag)
      expect(cacher.find_one.response[:status]).to eq('REQUESTED')
    end

    subject do
      described_class.new
    end

    it 'overwrites the existing record', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim') do
        expect(User).to receive(:find).with(user.uuid).once.and_return(user)
        expect_any_instance_of(EVSSClaimsRedisHelper).to receive(:cache_one).with(Hash).and_call_original
        subject.perform(user.uuid, claim.id)
        expect(cacher.find_one.response[:status]).to eq('SUCCESS')
      end
    end

    describe 'when job has failed' do
      it 'should set the status to FAILED' do
        expect_any_instance_of(EVSSClaimsRedisHelper).to receive(:cache_one).with(status: 'FAILED').and_call_original
        subject.sidekiq_retries_exhausted_block.call('args' => [user.uuid, claim.id])
        expect(cacher.find_one.response[:status]).to eq('FAILED')
      end
    end
  end
end
