# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CentralMail::SubmitSavedClaimJob, uploader_helpers: true do
  stub_virus_scan
  let(:pension_burial) { create(:pension_burial) }
  let(:claim) { pension_burial.saved_claim }
  let(:central_mail_submission) { claim.central_mail_submission }

  describe '#perform' do
    let(:job) { described_class.new }
    let(:success) { true }

    before do
      expect(job).to receive(:process_record).with(claim).and_return('pdf_path')
      expect(job).to receive(:process_record).with(pension_burial).and_return('attachment_path')
      expect(job).to receive(:to_faraday_upload).with('pdf_path').and_return('faraday1')
      expect(job).to receive(:to_faraday_upload).with('attachment_path').and_return('faraday1')
      expect(job).to receive(:generate_metadata).and_return(
        metadata: {}
      )
      expect_any_instance_of(CentralMail::Service).to receive(:upload).with(
        'metadata' => '{"metadata":{}}', 'document' => 'faraday1', 'attachment1' => 'faraday1'
      ).and_return(OpenStruct.new(success?: success))

      expect(File).to receive(:delete).with('pdf_path')
      expect(File).to receive(:delete).with('attachment_path')
    end

    context 'with an response error' do
      let(:success) { false }

      it 'raises CentralMailResponseError and updates submission to failed' do
        expect(Rails.logger).to receive(:warn).exactly(:once)
        expect { job.perform(claim.id) }.to raise_error(CentralMail::SubmitSavedClaimJob::CentralMailResponseError)
        expect(central_mail_submission.reload.state).to eq('failed')
      end
    end

    it 'submits the saved claim and updates submission to success' do
      expect(Rails.logger).to receive(:info).exactly(:twice)
      job.perform(claim.id)
      expect(central_mail_submission.reload.state).to eq('success')
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    it 'logs a distrinct error when retries are exhausted' do
      CentralMail::SubmitSavedClaimJob.within_sidekiq_retries_exhausted_block do
        expect(Rails.logger).to receive(:error).exactly(:once).with(
          'Failed all retries on CentralMail::SubmitSavedClaimJob, last error: An error occured'
        )
        expect(StatsD).to receive(:increment).with('worker.central_mail.submit_saved_claim_job.exhausted')
      end
    end
  end

  describe '#to_faraday_upload' do
    it 'converts a file to faraday upload object' do
      file_path = 'tmp/foo'
      expect(Faraday::UploadIO).to receive(:new).with(
        file_path,
        'application/pdf'
      )
      described_class.new.to_faraday_upload(file_path)
    end
  end

  describe '#process_record' do
    let(:path) { 'tmp/pdf_path' }

    it 'processes a record and add stamps' do
      record = double
      datestamp_double1 = double
      datestamp_double2 = double

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(CentralMail::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5).and_return('path2')
      expect(CentralMail::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      ).and_return('path3')

      expect(described_class.new.process_record(record)).to eq('path3')
    end

    it 'processes a 21P-530V2 record and add stamps' do
      record = double
      datestamp_double1 = double
      datestamp_double2 = double
      datestamp_double3 = double
      timestamp = claim.created_at
      form_id = '21P-530V2'

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(CentralMail::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5).and_return('path2')
      expect(CentralMail::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      ).and_return('path3')
      expect(CentralMail::DatestampPdf).to receive(:new).with('path3').and_return(datestamp_double3)
      expect(datestamp_double3).to receive(:run).with(
        text: 'Application Submitted on va.gov',
        x: 425,
        y: 675,
        text_only: true,
        timestamp:,
        page_number: 5,
        size: 9,
        template: 'lib/pdf_fill/forms/pdfs/21P-530V2.pdf',
        multistamp: true
      ).and_return(path)

      expect(described_class.new.process_record(record, timestamp, form_id)).to eq(path)
    end

    describe '#get_hash_and_pages' do
      it 'gets sha and number of pages' do
        expect(Digest::SHA256).to receive(:file).with('path').and_return(
          OpenStruct.new(hexdigest: 'hexdigest')
        )
        expect(PdfInfo::Metadata).to receive(:read).with('path').and_return(
          OpenStruct.new(pages: 2)
        )

        expect(described_class.new.get_hash_and_pages('path')).to eq(
          hash: 'hexdigest',
          pages: 2
        )
      end
    end

    describe '#generate_metadata' do
      let(:job) do
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
        job
      end

      context 'with a non us address' do
        before do
          form = JSON.parse(claim.form)
          form['claimantAddress']['country'] = 'AGO'
          claim.form = form.to_json
          claim.send(:remove_instance_variable, :@parsed_form)
        end

        it 'generates metadata with 00000 for zipcode' do
          expect(job.generate_metadata['zipCode']).to eq('00000')
        end
      end

      it 'generates the metadata', run_at: '2017-01-04 03:00:00 EDT' do
        expect(job.generate_metadata).to eq(
          'veteranFirstName' => 'WESLEY',
          'veteranLastName' => 'FORD',
          'fileNumber' => '796043735',
          'receiveDt' => '2017-01-04 01:00:00',
          'zipCode' => '90210',
          'uuid' => claim.guid,
          'source' => 'va.gov',
          'hashV' => 'hash1',
          'numberAttachments' => 1,
          'docType' => '21P-530',
          'numberPages' => 1,
          'ahash1' => 'hash2',
          'numberPages1' => 2
        )
      end

      context 'with bad metadata names' do
        let(:pension_burial) { create(:pension_burial_bad_names) }
        let(:claim) { pension_burial.saved_claim }

        it 'strips invalid characters from veteran name from the metadata', run_at: '2017-01-04 03:00:00 EDT' do
          expect(job.generate_metadata).to eq(
            'veteranFirstName' => 'WA',
            'veteranLastName' => 'Ford',
            'fileNumber' => '796043735',
            'receiveDt' => '2017-01-04 01:00:00',
            'zipCode' => '90210',
            'uuid' => claim.guid,
            'source' => 'va.gov',
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
end
