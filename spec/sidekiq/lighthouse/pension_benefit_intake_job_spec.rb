# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::PensionBenefitIntakeJob, uploader_helpers: true do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:pension_burial).saved_claim }

  describe '#perform' do
    let(:service) { double('service') }
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }

    before do
      allow(job).to receive(:process_pdf).and_return(pdf_path)

      allow(SavedClaim::Pension).to receive(:find).and_return(claim)
      allow(claim).to receive(:to_pdf).and_return(pdf_path)

      allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:upload_form).and_return(response)
    end

    it 'submits the saved claim successfully' do
      allow(response).to receive(:success?) { true }
      doc = { file: pdf_path, file_name: 'pdf' }

      expect(claim).to receive(:to_pdf)
      expect(job).to receive(:process_pdf).with(pdf_path)
      expect(job).to receive(:generate_form_metadata_lh).once
      expect(service).to receive(:upload_form).with(
        main_document: doc, attachments: [doc], form_metadata: anything)
      expect(job).to receive(:check_success).with(response, claim.id)
      expect(job).to receive(:cleanup_file_paths)

      job.perform(claim.id)
    end

  end # describe #perform
end # Rspec.describe