# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CentralMail::SubmitBenefitsIntakeClaim, uploader_helpers: true do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:veteran_readiness_employment_claim) }

  describe '#perform' do
    let(:service) { double('service') }
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }

    before do
      allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:location).and_return(location)
      allow(service).to receive(:upload_doc).and_return(response)
    end

    it 'submits the saved claim successfully' do
      allow(response).to receive(:success?).and_return(true)
      expect(job).to receive(:create_form_submission_attempt)
      expect(job).to receive(:generate_metadata).once
      expect(service).to receive(:upload_doc)
      job.perform(claim.id)
      expect(response.success?).to eq(true)
      expect(claim.form_submissions).not_to eq(nil)
    end

    it 'submits and gets a response error' do
      allow(response).to receive(:success?).and_return(false)
      allow(response).to receive(:body).and_return("There was an error submitting the claim")
      expect(job).to receive(:create_form_submission_attempt)
      expect(job).to receive(:generate_metadata).once
      expect(service).to receive(:upload_doc)
      expect { job.perform(claim.id) }.to raise_error(CentralMail::SubmitBenefitsIntakeClaim::BenefitsIntakeClaimError)
      expect(response.success?).to eq(false)
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

  describe 'sidekiq_retries_exhausted block' do
    it 'logs a distinct error when retries are exhausted' do
      CentralMail::SubmitBenefitsIntakeClaim.within_sidekiq_retries_exhausted_block do
        expect(Rails.logger).to receive(:error).exactly(:once)
        expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
      end
    end
  end
  # Rspec.describe
end
