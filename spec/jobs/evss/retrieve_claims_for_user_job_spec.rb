# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::RetrieveClaimsForUserJob, type: :job do
  let(:user) { create(:user, :loa3) }
  let(:cacher) { EVSSClaimsRedisHelper.new(user_uuid: user.uuid) }

  describe '#perform' do
    before do
      cacher.cache_collection(status: 'REQUESTED')
      expect(Sentry::TagRainbows).to receive(:tag)
      expect(cacher.find_collection.response[:status]).to eq('REQUESTED')
    end

    subject do
      described_class.new
    end

    it 'overwrites the existing record', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      VCR.use_cassette('evss/claims/claims') do
        expect(User).to receive(:find).with(user.uuid).once.and_return(user)
        expect_any_instance_of(EVSSClaimsRedisHelper).to receive(:cache_collection).and_call_original
        subject.perform(user.uuid)
        expect(cacher.find_collection.response[:status]).to eq('SUCCESS')
      end
    end

    describe 'when job has failed' do
      it 'should set the status to FAILED' do
        expect_any_instance_of(EVSSClaimsRedisHelper).to(
          receive(:cache_collection).with(status: 'FAILED').and_call_original
        )
        subject.sidekiq_retries_exhausted_block.call('args' => [user.uuid])
        expect(cacher.find_collection.response[:status]).to eq('FAILED')
      end
    end
  end
end
