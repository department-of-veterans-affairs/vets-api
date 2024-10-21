# frozen_string_literal: true

require 'rails_helper'

describe VRE::Submit1900Job do
  describe '#perform' do
    subject { described_class.new.perform(claim.id, encrypted_user) }

    let(:user_struct) do
      OpenStruct.new(
        edipi: '1007697216',
        birls_id: '796043735',
        participant_id: '600061742',
        pid: '600061742',
        birth_date: '1986-05-06T00:00:00+00:00'.to_date,
        ssn: '796043735',
        vet360_id: '1781151',
        loa3?: true,
        icn: '1013032368V065534',
        uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
        va_profile_email: 'test@test.com'
      )
    end
    let(:encrypted_user) { KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json) }
    let(:user) { OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user))) }
    let(:claim) { create(:veteran_readiness_employment_claim) }

    before do
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
