# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitSavedClaimJob, uploader_helpers: true do
  describe '#perform' do
    stub_virus_scan

    let(:pension_burial) { create(:pension_burial) }
    let(:claim) { pension_burial.saved_claim }

    it 'submits the saved claim' do
      SubmitSavedClaimJob.new.perform(claim.id)
    end
  end

  describe '#to_faraday_upload' do
    it 'should convert a file to faraday upload object' do
      file_path = 'tmp/foo'
      expect(Faraday::UploadIO).to receive(:new).with(
        file_path,
        'application/pdf'
      )
      described_class.new.to_faraday_upload(file_path)
    end
  end
end
