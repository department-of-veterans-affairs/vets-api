# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitSavedClaimJob, uploader_helpers: true do
  stub_virus_scan
  let(:pension_burial) { create(:pension_burial) }
  let(:claim) { pension_burial.saved_claim }

  describe '#perform' do
    it 'submits the saved claim' do
      job = described_class.new

      expect(job).to receive(:process_record).with(claim).and_return('pdf_path')
      expect(job).to receive(:process_record).with(pension_burial).and_return('attachment_path')
      expect(job).to receive(:to_faraday_upload).with('pdf_path').and_return('faraday1')
      expect(job).to receive(:to_faraday_upload).with('attachment_path').and_return('faraday1')
      expect(job).to receive(:generate_metadata).and_return(
        metadata: {}
      )
      # expect_any_instance_of(PensionBurial::Service).to receive(:upload).with(
      #   'metadata' => '{"metadata":{}}', 'document' => 'faraday1', 'attachment1' => 'faraday1'
      # )

      expect(File).to receive(:delete).with('pdf_path')
      expect(File).to receive(:delete).with('attachment_path')

      job.perform(claim.id)
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

    describe '#generate_metadata' do
      it 'should generate the metadata', run_at: '2017-01-04 03:00:00 EDT' do
        job = described_class.new
        job.instance_variable_set('@claim', claim)
        job.instance_variable_set('@pdf_path', 'pdf_path')
        job.instance_variable_set('@attachment_paths', ['attachment_path'])

        expect(job).to receive(:get_hash_and_pages).with('pdf_path').and_return(
          hash: 'hash1',
          pages: 1
        )
        expect(job).to receive(:get_hash_and_pages).with('attachment_path').and_return(
          hash: 'hash2',
          pages: 2
        )

        expect(job.generate_metadata).to eq(
          'veteranFirstName' => 'Test',
          'veteranLastName' => 'User',
          'fileNumber' => '111223333',
          'receiveDt' => '2017-01-04 01:00:00',
          'zipCode' => '90210',
          'uuid' => claim.guid,
          'source' => 'Vets.gov',
          'hashV' => 'hash1',
          'numberAttachments' => 1,
          'docType' => '21P-530',
          'numberPages' => 1,
          'ahash1' => 'hash2',
          'numberPages1' => 2
        )
      end
    end
  end
end
