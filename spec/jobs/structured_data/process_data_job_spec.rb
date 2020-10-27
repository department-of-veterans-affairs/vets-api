# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StructuredData::ProcessDataJob, uploader_helpers: true do
  stub_virus_scan
  let(:pension_burial) { create(:pension_burial) }
  let(:claim) { pension_burial.saved_claim }

  describe '#perform' do
    let(:job) { StructuredData::ProcessDataJob.new }
    let(:bip_claims) { instance_double(BipClaims::Service) }

    before do
      allow(BipClaims::Service).to receive(:new).and_return(bip_claims)
      allow(bip_claims).to receive(:lookup_veteran_from_mpi).and_return(
        OpenStruct.new(participant_id: 123)
      )
    end

    it 'attempts Veteran MVI lookup' do
      expect(bip_claims).to receive(:lookup_veteran_from_mpi).with(claim).and_return(
        OpenStruct.new(participant_id: 123)
      )
      job.perform(claim.id)
    end

    it 'calls Central Mail processing job' do
      expect(CentralMail::SubmitSavedClaimJob).to receive(:perform_async)
      job.perform(claim.id)
    end

    it 'increments metric for successful claim submission to va.gov' do
      expect(StatsD).to receive(:increment).at_least(:once)
      job.perform(claim.id)
    end
  end
end
