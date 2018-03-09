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

  describe '#process_record' do
    it 'should process a record and add stamps' do
      record = double
      datestamp_double1 = double
      datestamp_double2 = double

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(PensionBurial::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VETS.GOV', x: 5, y: 5).and_return('path2')
      expect(PensionBurial::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - Vets.gov Submission',
        x: 429,
        y: 770,
        text_only: true
      ).and_return('path3')

      expect(described_class.new.process_record(record)).to eq('path3')
    end

    describe '#get_hash_and_pages' do
      it 'should get sha and number of pages' do
        expect(Digest::SHA256).to receive(:file).with('path').and_return(
          OpenStruct.new(hexdigest: 'hexdigest')
        )
        expect(PDF::Reader).to receive(:new).with('path').and_return(
          OpenStruct.new(pages: [1, 2])
        )

        expect(described_class.new.get_hash_and_pages('path')).to eq(
          hash: 'hexdigest',
          pages: 2
        )
      end
    end
  end
end
