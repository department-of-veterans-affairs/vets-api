# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'burials/benefits_intake/submit_claim_job'
require 'burials/monitor'
require 'burials/notification_email'

RSpec.describe Burials::BenefitsIntake::SubmitClaimJob, :uploader_helpers do
  stub_virus_scan

  let(:job) { described_class.new }
  let(:claim) { create(:burials_saved_claim) }
  let(:service) { double('service') }
  let(:monitor) { Burials::Monitor.new }
  let(:user_account_uuid) { 123 }

  describe '#perform' do
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }

    before do
      allow(Flipper).to receive(:enabled?).with(:validate_saved_claims_with_json_schemer).and_return(true)

      job.instance_variable_set(:@claim, claim)
      allow(Burials::SavedClaim).to receive(:find).and_return(claim)
      allow(claim).to receive_messages(to_pdf: pdf_path, persistent_attachments: [])

      job.instance_variable_set(:@intake_service, service)
      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:request_upload)
      allow(service).to receive_messages(location:, perform_upload: response)
      allow(response).to receive(:success?).and_return true

      job.instance_variable_set(:@monitor, monitor)
    end

    context 'Feature burial_submitted_email_notification=false' do
      it 'submits the saved claim successfully' do
        allow(Flipper).to receive(:enabled?).with(:burial_submitted_email_notification).and_return(false)
        allow(job).to receive_messages(process_document: pdf_path, form_submission_pending_or_success: false)

        expect(FormSubmission).to receive(:create)
        expect(FormSubmissionAttempt).to receive(:create)
        expect(Datadog::Tracing).to receive(:active_trace)
        expect(UserAccount).to receive(:find)

        expect(service).to receive(:perform_upload).with(
          upload_url: 'test_location', document: pdf_path, metadata: anything, attachments: []
        )

        expect(job).to receive(:send_confirmation_email)
        expect(job).not_to receive(:send_submitted_email)
        expect(job).to receive(:cleanup_file_paths)

        job.perform(claim.id, :user_uuid)
      end
    end

    context 'Feature burial_submitted_email_notification=true' do
      it 'submits the saved claim successfully' do
        allow(Flipper).to receive(:enabled?).with(:burial_submitted_email_notification).and_return(true)
        allow(job).to receive_messages(process_document: pdf_path, form_submission_pending_or_success: false)

        expect(FormSubmission).to receive(:create)
        expect(FormSubmissionAttempt).to receive(:create)
        expect(Datadog::Tracing).to receive(:active_trace)
        expect(UserAccount).to receive(:find)

        expect(service).to receive(:perform_upload).with(
          upload_url: 'test_location', document: pdf_path, metadata: anything, attachments: []
        )

        expect(job).not_to receive(:send_confirmation_email)
        expect(job).to receive(:send_submitted_email)
        expect(job).to receive(:cleanup_file_paths)

        job.perform(claim.id, :user_uuid)
      end
    end

    it 'is unable to find user_account' do
      expect(Burials::SavedClaim).not_to receive(:find)
      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).not_to receive(:send_confirmation_email)
      expect(job).not_to receive(:send_submitted_email)
      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        ActiveRecord::RecordNotFound,
        "Couldn't find UserAccount with 'id'=user_account_uuid"
      )
    end

    it 'is unable to find saved_claim_id' do
      allow(Burials::SavedClaim).to receive(:find).and_return(nil)

      expect(UserAccount).to receive(:find)

      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).not_to receive(:send_confirmation_email)
      expect(job).not_to receive(:send_submitted_email)
      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        Burials::BenefitsIntake::SubmitClaimJob::BurialsBenefitIntakeError,
        "Unable to find Burials::SavedClaim #{claim.id}"
      )
    end

    # perform
  end

  describe '#form_submission_pending_or_success' do
    before do
      job.instance_variable_set(:@claim, claim)
      allow(Burials::SavedClaim).to receive(:find).and_return(claim)
    end

    context 'with no form submissions' do
      it 'returns false' do
        expect(job.send(:form_submission_pending_or_success)).to be(false).or be_nil
      end
    end

    context 'with pending form submission attempt' do
      let(:claim) { create(:burials_saved_claim, :pending) }

      it 'return true' do
        expect(job.send(:form_submission_pending_or_success)).to be(true)
      end
    end

    context 'with success form submission attempt' do
      let(:claim) { create(:burials_saved_claim, :success) }

      it 'return true' do
        expect(job.send(:form_submission_pending_or_success)).to be(true)
      end
    end

    context 'with failure form submission attempt' do
      let(:claim) { create(:burials_saved_claim, :failure) }

      it 'return false' do
        expect(job.send(:form_submission_pending_or_success)).to be(false)
      end
    end
  end

  describe '#process_document' do
    let(:service) { double('service') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:datestamp_pdf_double) { instance_double(PDFUtilities::DatestampPdf) }

    before do
      job.instance_variable_set(:@intake_service, service)
      job.instance_variable_set(:@claim, claim)
    end

    it 'returns a datestamp pdf path' do
      run_count = 0
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_pdf_double)
      allow(datestamp_pdf_double).to receive(:run) {
        run_count += 1
        pdf_path
      }
      allow(service).to receive(:valid_document?).and_return(pdf_path)
      new_path = job.send(:process_document, 'test/path')

      expect(new_path).to eq(pdf_path)
      expect(run_count).to eq(3)
    end

    it 'requests specific pdf stamps' do
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_pdf_double)
      expect(datestamp_pdf_double).to receive(:run).with(
        text: 'VA.GOV',
        timestamp: claim.created_at,
        x: 5,
        y: 5
      ).and_return(pdf_path)

      expect(datestamp_pdf_double).to receive(:run).with(
        text: 'FDC Reviewed - VA.gov Submission',
        timestamp: claim.created_at,
        x: 400,
        y: 770,
        text_only: true
      ).and_return(pdf_path)

      expect(datestamp_pdf_double).to receive(:run).with(
        text: 'Application Submitted on va.gov',
        x: 425,
        y: 675,
        text_only: true, # passing as text only because we override how the date is stamped in this instance
        timestamp: claim.created_at,
        page_number: 5,
        size: 9,
        template: Burials::PDF_PATH,
        multistamp: true
      ).and_return(pdf_path)

      expect(service).to receive(:valid_document?).and_return(pdf_path)

      new_path = job.send(:process_document, 'test/path')

      expect(new_path).to eq(pdf_path)
    end

    it 'successfully stamps the generated pdf' do
      expect(service).to receive(:valid_document?).and_return(pdf_path)
      new_path = job.send(:process_document, claim.to_pdf)
      expect(new_path).to eq(pdf_path)
    end
    # process_document
  end

  describe '#cleanup_file_paths' do
    before do
      job.instance_variable_set(:@form_path, 'path/file.pdf')
      job.instance_variable_set(:@attachment_paths, '/invalid_path/should_be_an_array.failure')

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_file_cleanup_error)
    end

    it 'errors and logs but does not reraise' do
      expect(monitor).to receive(:track_file_cleanup_error)
      job.send(:cleanup_file_paths)
    end
  end

  describe '#send_confirmation_email' do
    let(:monitor_error) { create(:monitor_error) }
    let(:notification) { double('notification') }

    before do
      job.instance_variable_set(:@claim, claim)

      allow(Burials::NotificationEmail).to receive(:new).and_return(notification)
      allow(notification).to receive(:deliver).and_raise(monitor_error)

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_send_email_failure)
    end

    it 'errors and logs but does not reraise' do
      expect(Burials::NotificationEmail).to receive(:new).with(claim.id)
      expect(notification).to receive(:deliver).with(:confirmation)
      expect(monitor).to receive(:track_send_email_failure)
      job.send(:send_confirmation_email)
    end
  end

  describe '#send_submitted_email' do
    let(:monitor_error) { create(:monitor_error) }
    let(:notification) { double('notification') }

    before do
      job.instance_variable_set(:@claim, claim)

      allow(Burials::NotificationEmail).to receive(:new).and_return(notification)
      allow(notification).to receive(:deliver).and_raise(monitor_error)

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_send_email_failure)
    end

    it 'errors and logs but does not reraise' do
      expect(Burials::NotificationEmail).to receive(:new).with(claim.id)
      expect(notification).to receive(:deliver).with(:submitted)
      expect(monitor).to receive(:track_send_email_failure)
      job.send(:send_submitted_email)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    let(:exhaustion_msg) do
      { 'args' => [], 'class' => 'Burials::BenefitsIntake::SubmitClaimJob', 'error_message' => 'An error occurred',
        'queue' => 'low' }
    end

    before do
      allow(Burials::Monitor).to receive(:new).and_return(monitor)
    end

    context 'when retries are exhausted' do
      it 'logs a distinct error when no claim_id provided' do
        Burials::BenefitsIntake::SubmitClaimJob.within_sidekiq_retries_exhausted_block do
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end

      it 'logs a distinct error when only claim_id provided' do
        Burials::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
          allow(Burials::SavedClaim).to receive(:find).and_return(claim)
          expect(Burials::SavedClaim).to receive(:find).with(claim.id)

          exhaustion_msg['args'] = [claim.id]

          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distinct error when claim_id and user_uuid provided' do
        Burials::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, 2] }) do
          allow(Burials::SavedClaim).to receive(:find).and_return(claim)
          expect(Burials::SavedClaim).to receive(:find).with(claim.id)

          exhaustion_msg['args'] = [claim.id, 2]

          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distinct error when claim is not found' do
        Burials::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1, 2] }) do
          expect(Burials::SavedClaim).to receive(:find).with(claim.id - 1)

          exhaustion_msg['args'] = [claim.id - 1, 2]

          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end
    end
  end

  # Rspec.describe
end
