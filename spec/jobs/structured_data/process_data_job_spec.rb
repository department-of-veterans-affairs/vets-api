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
      allow(bip_claims).to receive(:lookup_veteran_from_mvi).and_return(
        OpenStruct.new(participant_id: 123)
      )
    end

    it 'attempts Veteran MVI lookup' do
      expect(bip_claims).to receive(:lookup_veteran_from_mvi).with(claim).and_return(
        OpenStruct.new(participant_id: 123)
      )
      job.perform(claim.id)
    end

    it 'calls Central Mail processing job with SD flipper disabled' do
      Flipper.disable(:burial_claim_sd_workflow)
      expect(CentralMail::SubmitSavedClaimJob).to receive(:perform_async)
      job.perform(claim.id)
    end

    describe 'if structured data workflow fails' do
      before { allow_any_instance_of(VBMS::Efolder::UploadClaimAttachments).to receive(:upload!).and_raise('500') }

      it 'defaults to Central Mail workflow' do
        expect(CentralMail::SubmitSavedClaimJob).to receive(:perform_async)
        job.perform(claim.id)
      end
    end

    it 'increments metric for successful claim submission to va.gov' do
      expect(StatsD).to receive(:increment).at_least(:once)
      job.perform(claim.id)
    end
  end
end
