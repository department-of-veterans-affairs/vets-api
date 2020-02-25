# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StructuredData::ProcessDataJob, uploader_helpers: true do
  stub_virus_scan
  let(:pension_burial) { create(:pension_burial) }
  let(:claim) { pension_burial.saved_claim }

  describe '#perform' do
    let(:job) { described_class.new }

    before do
      described_class.new.perform(claim.id)
    end

    it 'attempts Veteran MVI lookup' do
      expect_any_instance_of(BipClaims::Service).to receive(:lookup_veteran_from_mvi).with(claim).and_return(
        OpenStruct.new(participant_id: 123)
      )
    end

    it 'calls Central Mail process attachments' do
      expect(claim).to receive(:process_attachments)
    end

    it 'increments metric for successful claim submission to va.gov' do
      expect(StatsD).to receive(:increment).at_least(:once)
    end
  end
end
