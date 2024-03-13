# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CentralMail::SubmitBenefitsIntakeClaim, uploader_helpers: true do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:veteran_readiness_employment_claim) }
  let(:benefits_intake_service) { instance_double(BenefitsIntakeService::Service) }

  describe '#perform' do
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }
    let(:success) { true }

    before do
      allow(benefits_intake_service).to receive(:upload_doc).and_return(success)
    end

    it 'submits the saved claim successfully' do
      doc = { file: pdf_path, file_name: 'pdf' }
      expect(job).to receive(:create_form_submission_attempt)
      expect(job).to receive(:generate_metadata).once
      expect(benefits_intake_service).to receive(:upload_doc).with(
        upload_url: 'test_location', file: doc, metadata: anything, attachments: []
      ).and_return(success)

      job.perform(claim.id)
    end
    # perform
  end

  describe '#process_record' do
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
        x: 429,
        y: 770,
        text_only: true
      ).and_return('path3')

      expect(described_class.new.process_record(record)).to eq('path3')
    end
  end
  # Rspec.describe
end
