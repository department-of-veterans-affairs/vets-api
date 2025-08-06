# frozen_string_literal: true
require 'rails_helper'
require AccreditedRepresentativePortal::Engine.root / 'spec/spec_helper'

RSpec.describe AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob, :uploader_helpers do
  stub_virus_scan

  let(:job) { described_class.new }
  let(:claim) { create(:saved_claim_benefits_intake) }
  let(:lighthouse_service) { double('lighthouse_service') }
  let(:intake_service) { double('intake_service') }
  let(:monitor) { double('monitor') }

  describe '#perform' do
    let(:response) { double('response', success?: true, body: 'success') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }
    let(:uuid) { 'test-uuid' }

    before do
      job.instance_variable_set(:@claim, claim)
      job.instance_variable_set(:@lighthouse_service, lighthouse_service)
      job.instance_variable_set(:@intake_service, intake_service)
      job.instance_variable_set(:@user_account_uuid, '123-456-789')
      job.instance_variable_set(:@monitor, monitor)

      allow(lighthouse_service).to receive_messages(uuid: uuid, location: location, upload_doc: response)
      allow(intake_service).to receive(:valid_document?).and_return(pdf_path)
      allow(monitor).to receive(:track_submission_success)
      allow(job).to receive(:init).and_return(nil)
      allow(job).to receive(:process_record).and_return(pdf_path)
      allow(job).to receive(:create_form_submission_attempt).and_return(nil)
      allow(job).to receive(:send_confirmation_email).and_return(nil)
      allow(job).to receive(:cleanup_file_paths).and_return(nil)
    end

    it 'performs' do
      expect(job).to receive(:process_record).with(claim)
      expect(job).to receive(:create_form_submission_attempt)
      expect(lighthouse_service).to receive(:upload_doc).with(
        upload_url: location,
        file: { file: pdf_path, file_name: 'pdf' },
        metadata: "{\"veteranFirstName\":\"John\",\"veteranLastName\":\"Doe\",\"fileNumber\":\"123456789\",\"zipCode\":\"12345\",\"source\":\"AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim va.gov\",\"docType\":\"21-686c\",\"businessLine\":\"CMP\"}",
        attachments: []
      )
      expect(job).to receive(:send_confirmation_email)
      expect(job).to receive(:cleanup_file_paths)

      result = job.perform(claim.id)
      expect(result).to eq(uuid)
    end

    context 'submission has additional documentation' do
      around { |example| Timecop.freeze { example.run } }
      
      let(:stamper) { double }
      let(:va_form_attachment) { create(:persistent_attachment_va_form_documentation, form_id: '21-686c') }

      before do
        # Override the process_record method to actually call stamp_pdf
        allow(job).to receive(:process_record).and_call_original
        allow(job).to receive(:stamp_pdf).and_call_original
        
        # Set up the claim to have attachments that will trigger stamping
        allow(claim).to receive(:persistent_attachments).and_return([va_form_attachment])
        
        # Mock the valid_document? method on lighthouse_service as well
        allow(lighthouse_service).to receive(:valid_document?).and_return(pdf_path)
      end

      it 'stamps the footer of the additional docs' do
        timestamp = DateTime.now.utc.strftime('%H:%M:%S  %Y-%m-%d %I:%M %p')
        
        # mock stamping of provided VA form
        allow(SimpleFormsApi::PdfStamper).to receive(:new).and_return(stamper)
        allow(stamper).to receive(:stamp_pdf)
        
        # Mock the to_pdf method to return a path
        allow(va_form_attachment).to receive(:to_pdf).and_return('/tmp/test.pdf')
        
        # Mock PDFUtilities::DatestampPdf instead of expecting the real class
        datestamp_pdf_double = double('datestamp_pdf')
        allow(PDFUtilities::DatestampPdf).to receive(:new).with('/tmp/test.pdf').and_return(datestamp_pdf_double)
        expect(datestamp_pdf_double).to receive(:run).with(
          text: "Submitted via VA.gov at #{timestamp} UTC. Signed in and submitted with an identity-verified account.",
          text_only: true, 
          x: 5, 
          y: 5
        )
        
        job.perform(claim.id)
      end
    end
  end

  describe '#send_confirmation_email' do
    let(:notification) { double('notification') }
    let(:intake_service) { double('intake_service') }
    let(:user_account_uuid) { '123-456-789' }

    before do
      job.instance_variable_set(:@claim, claim)
      job.instance_variable_set(:@intake_service, intake_service)
      job.instance_variable_set(:@user_account_uuid, user_account_uuid)
      job.instance_variable_set(:@monitor, monitor)
    end

    context 'when email sends successfully' do
      it 'sends a confirmation email' do
        allow(AccreditedRepresentativePortal::NotificationEmail).to receive(:new).with(claim.id).and_return(notification)
        expect(notification).to receive(:deliver).with(:confirmation)

        job.send(:send_confirmation_email)
      end
    end

    context 'when email sending fails' do
      let(:email_error) { StandardError.new('Email delivery failed') }

      it 'logs the error but does not reraise' do
        allow(AccreditedRepresentativePortal::NotificationEmail).to receive(:new).with(claim.id).and_return(notification)
        allow(notification).to receive(:deliver).with(:confirmation).and_raise(email_error)
        expect(monitor).to receive(:track_send_email_failure).with(claim, intake_service, user_account_uuid, 'confirmation', email_error)

        expect { job.send(:send_confirmation_email) }.not_to raise_error
      end
    end
  end
end
