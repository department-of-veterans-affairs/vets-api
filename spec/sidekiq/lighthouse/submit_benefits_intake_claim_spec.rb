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

      allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive_messages(location:, upload_doc: response)
    end

    it 'submits the saved claim successfully' do
      allow(service).to receive(:valid_document?).and_return(pdf_path)
      allow(response).to receive(:success?).and_return(true)

      expect(job).to receive(:create_form_submission_attempt)
      expect(job).to receive(:generate_metadata).once.and_call_original
      expect(job).to receive(:send_confirmation_email).once
      expect(service).to receive(:upload_doc)

      expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.success')

      job.perform(claim.id)

      expect(response.success?).to be(true)
      expect(claim.form_submissions).not_to be_nil
      expect(claim.business_line).not_to be_nil
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
      expect(response.success?).to be(false)
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

    it 'processes a 21P-530EZ record and add stamps' do
      record = double
      allow(record).to receive_messages({ created_at: claim.created_at })
      datestamp_double1 = double
      datestamp_double2 = double
      double
      timestamp = claim.created_at

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5,
                                                      timestamp:).and_return('path2')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      ).and_return('path3')

      expect(service).to receive(:valid_document?).and_return(path)

      expect(job.process_record(record)).to eq(path)
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
