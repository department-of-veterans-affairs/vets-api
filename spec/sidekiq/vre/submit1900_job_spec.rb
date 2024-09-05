# frozen_string_literal: true

require 'rails_helper'

describe VRE::Submit1900Job do
  describe '#perform' do
    subject { described_class.new.perform(claim.id, user.uuid) }

    let(:user) { create(:evss_user) }
    let(:claim) { create(:veteran_readiness_employment_claim) }

    before do
      allow(User).to receive(:find).and_return(user)
      allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
    end

    after do
      subject
    end

    it 'calls claim.add_claimant_info' do
      allow(claim).to receive(:send_to_lighthouse!)
      allow(claim).to receive(:send_to_res)

      expect(claim).to receive(:add_claimant_info).with(user)
    end

    it 'calls claim.send_to_vre' do
      expect(claim).to receive(:send_to_vre).with(user)
    end
  end

  describe 'raises an exception' do
    it 'when queue is exhausted' do
      VRE::Submit1900Job.within_sidekiq_retries_exhausted_block do
        expect(Rails.logger).to receive(:error).exactly(:once).with(
          'Failed all retries on VRE::Submit1900Job, last error: An error occured'
        )
        expect(StatsD).to receive(:increment).with('worker.vre.submit_1900_job.exhausted')
      end
    end
  end
end
