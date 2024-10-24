# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::SubmitBenefitsIntakeClaim, :uploader_helpers do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:pension_burial) { create(:pension_burial) }
  let(:claim) { pension_burial.saved_claim }

  describe '#perform' do
    let(:service) { double('service') }
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }
    let(:notification) { double('notification') }

    before do
      job.instance_variable_set(:@claim, claim)
      allow(SavedClaim).to receive(:find).and_return(claim)

      Flipper.enable(:va_burial_v2)

      allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive_messages(location:, upload_doc: response)

      allow(Burials::NotificationEmail).to receive(:new).and_return(notification)
      allow(notification).to receive(:deliver)
    end

    it 'submits the saved claim successfully' do
      allow(service).to receive(:valid_document?).and_return(pdf_path)
      allow(response).to receive(:success?).and_return(true)

      expect(job).to receive(:create_form_submission_attempt)
      expect(job).to receive(:generate_metadata).once
      expect(service).to receive(:upload_doc)

      # burials only
      expect(notification).to receive(:deliver).with(:confirmation)

      expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.success')

      job.perform(claim.id)

      expect(response.success?).to eq(true)
      expect(claim.form_submissions).not_to eq(nil)
      expect(claim.business_line).not_to eq(nil)
    end

    it 'submits and gets a response error' do
      allow(service).to receive(:valid_document?).and_return(pdf_path)
      allow(response).to receive_messages(success?: false, body: 'There was an error submitting the claim')
      expect(job).to receive(:create_form_submission_attempt)
      expect(job).to receive(:generate_metadata).once
      expect(service).to receive(:upload_doc)
      expect(Rails.logger).to receive(:warn)
      expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.failure')
      expect { job.perform(claim.id) }.to raise_error(Lighthouse::SubmitBenefitsIntakeClaim::BenefitsIntakeClaimError)
      expect(response.success?).to eq(false)
    end

    it 'handles an invalid document' do
      allow(service).to receive(:valid_document?).and_raise(BenefitsIntakeService::Service::InvalidDocumentError)
      expect(Rails.logger).to receive(:warn)
      expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.document_upload_error')
      expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.failure')
      expect { job.perform(claim.id) }.to raise_error(BenefitsIntakeService::Service::InvalidDocumentError)
    end
    # perform
  end

  describe '#process_record' do
    let(:path) { 'tmp/pdf_path' }
    let(:service) { double('service') }

    before do
      allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
      job.init(claim.id)
    end

    it 'processes a record and add stamps' do
      record = double
      datestamp_double1 = double
      datestamp_double2 = double

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5, timestamp: nil).and_return('path2')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      ).and_return('path3')
      allow(service).to receive(:valid_document?).and_return('path3')

      expect(job.process_record(record)).to eq('path3')
    end

    it 'processes a 21P-530V2 record and add stamps' do
      record = double
      datestamp_double1 = double
      datestamp_double2 = double
      datestamp_double3 = double
      timestamp = claim.created_at
      form_id = '21P-530V2'

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5, timestamp:).and_return('path2')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      ).and_return('path3')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path3').and_return(datestamp_double3)
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
      allow(service).to receive(:valid_document?).and_return(path)

      expect(job.process_record(record, timestamp, form_id)).to eq(path)
    end

    it 'handles an invalid record' do
      record = double
      datestamp_double1 = double
      datestamp_double2 = double

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5, timestamp: nil).and_return('path2')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      ).and_return('path3')
      allow(service).to receive(:valid_document?).and_raise(BenefitsIntakeService::Service::InvalidDocumentError)
      expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.document_upload_error')

      expect { job.process_record(record) }.to raise_error(BenefitsIntakeService::Service::InvalidDocumentError)
    end

    it 'handles an invalid 21P-530V2 record' do
      record = double
      datestamp_double1 = double
      datestamp_double2 = double
      datestamp_double3 = double
      timestamp = claim.created_at
      form_id = '21P-530V2'

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5, timestamp:).and_return('path2')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      ).and_return('path3')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path3').and_return(datestamp_double3)
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
      allow(service).to receive(:valid_document?).and_raise(BenefitsIntakeService::Service::InvalidDocumentError)
      expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.document_upload_error')

      expect do
        job.process_record(record, timestamp, form_id)
      end.to raise_error(BenefitsIntakeService::Service::InvalidDocumentError)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    it 'logs a distinct error when retries are exhausted' do
      Lighthouse::SubmitBenefitsIntakeClaim.within_sidekiq_retries_exhausted_block do
        expect(Rails.logger).to receive(:error).exactly(:once)
        expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.exhausted')
      end
    end
  end
  # Rspec.describe
end
