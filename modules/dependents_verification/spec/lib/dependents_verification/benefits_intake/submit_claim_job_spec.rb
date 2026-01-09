# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'dependents_verification/benefits_intake/submit_claim_job'
require 'dependents_verification/monitor'
require 'dependents_verification/notification_email'

RSpec.describe DependentsVerification::BenefitsIntake::SubmitClaimJob, :uploader_helpers do
  stub_virus_scan

  let(:job) { described_class.new }
  let(:claim) { create(:dependents_verification_claim, veteran_ssn: '999999999') }
  let(:service) { double('service') }
  let(:monitor) { DependentsVerification::Monitor.new }
  let(:user_account_uuid) { 123 }

  describe '#perform' do
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }

    before do
      allow(Flipper).to receive(:enabled?).with(:validate_saved_claims_with_json_schemer).and_return(true)

      job.instance_variable_set(:@claim, claim)
      allow(DependentsVerification::SavedClaim).to receive(:find).and_return(claim)
      allow(claim).to receive(:to_pdf).with(claim.id).and_return(pdf_path)
      allow(claim).to receive(:persistent_attachments).and_return([])
      allow(claim).to receive_messages(to_pdf: pdf_path)

      job.instance_variable_set(:@intake_service, service)
      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:request_upload)
      allow(service).to receive_messages(location:, perform_upload: response)
      allow(response).to receive(:success?).and_return true

      allow_any_instance_of(DependentsVerification::NotificationEmail).to receive(:deliver)

      job.instance_variable_set(:@monitor, monitor)
    end

    it 'submits the saved claim successfully' do
      allow(job).to receive(:process_document).and_return(pdf_path)

      expect(Lighthouse::Submission).to receive(:create)
      expect(Lighthouse::SubmissionAttempt).to receive(:create)
      expect(Datadog::Tracing).to receive(:active_trace)
      expect(UserAccount).to receive(:find)

      expect(service).to receive(:perform_upload).with(
        upload_url: 'test_location', document: pdf_path, metadata: anything, attachments: []
      )
      expect(job).to receive(:cleanup_file_paths)

      job.perform(claim.id, :user_account_uuid)
    end

    it 'is unable to find user_account' do
      expect(DependentsVerification::SavedClaim).not_to receive(:find)
      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).not_to receive(:send_submitted_email)
      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        ActiveRecord::RecordNotFound,
        /Couldn't find UserAccount/
      )
    end

    it 'is unable to find saved_claim_id' do
      allow(DependentsVerification::SavedClaim).to receive(:find).and_return(nil)

      expect(UserAccount).to receive(:find)

      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).not_to receive(:send_submitted_email)
      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        DependentsVerification::BenefitsIntake::SubmitClaimJob::DependentsVerificationBenefitsIntakeError,
        "Unable to find DependentsVerification::SavedClaim #{claim.id}"
      )
    end
  end

  describe '#lighthouse_submission_pending_or_success' do
    before do
      job.instance_variable_set(:@claim, claim)
      allow(DependentsVerification::SavedClaim).to receive(:find).and_return(claim)
    end

    context 'with no form submissions' do
      it 'returns false' do
        expect(job.send(:lighthouse_submission_pending_or_success)).to be(false).or be_nil
      end
    end

    context 'with pending form submission attempt' do
      let(:claim) { create(:dependents_verification_claim, :pending) }

      it 'returns true' do
        expect(job.send(:lighthouse_submission_pending_or_success)).to be(true)
      end
    end

    context 'with success form submission attempt' do
      let(:claim) { create(:dependents_verification_claim, :submitted) }

      it 'returns true' do
        expect(job.send(:lighthouse_submission_pending_or_success)).to be(true)
      end
    end

    context 'with failure form submission attempt' do
      let(:claim) { create(:dependents_verification_claim, :failure) }

      it 'returns false' do
        expect(job.send(:lighthouse_submission_pending_or_success)).to be(false)
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
      expect(run_count).to eq(2)
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

  describe '#send_submitted_email' do
    let(:monitor_error) { create(:monitor_error) }
    let(:notification) { double('notification') }

    before do
      job.instance_variable_set(:@claim, claim)

      allow(DependentsVerification::NotificationEmail).to receive(:new).and_return(notification)
      allow(notification).to receive(:deliver).and_raise(monitor_error)

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_send_email_failure)
    end

    it 'errors and logs but does not reraise' do
      expect(DependentsVerification::NotificationEmail).to receive(:new).with(claim.id)
      expect(notification).to receive(:deliver).with(:submitted)
      expect(monitor).to receive(:track_send_email_failure)
      job.send(:send_submitted_email)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    let(:exhaustion_msg) do
      { 'args' => [], 'class' => 'DependentsVerification::BenefitsIntake::SubmitClaimJob',
        'error_message' => 'An error occurred',
        'queue' => 'low' }
    end

    before do
      allow(DependentsVerification::Monitor).to receive(:new).and_return(monitor)
    end

    context 'when retries are exhausted' do
      it 'logs a distinct error when no claim_id provided' do
        DependentsVerification::BenefitsIntake::SubmitClaimJob.within_sidekiq_retries_exhausted_block do
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end

      it 'logs a distinct error when only claim_id provided' do
        DependentsVerification::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
            allow(DependentsVerification::SavedClaim).to receive(:find).and_return(claim)
            expect(DependentsVerification::SavedClaim).to receive(:find).with(claim.id)

            exhaustion_msg['args'] = [claim.id]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distinct error when claim_id and user_uuid provided' do
        DependentsVerification::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, 2] }) do
            allow(DependentsVerification::SavedClaim).to receive(:find).and_return(claim)
            expect(DependentsVerification::SavedClaim).to receive(:find).with(claim.id)

            exhaustion_msg['args'] = [claim.id, 2]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distinct error when claim is not found' do
        DependentsVerification::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1, 2] }) do
            expect(DependentsVerification::SavedClaim).to receive(:find).with(claim.id - 1)

            exhaustion_msg['args'] = [claim.id - 1, 2]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end
    end
  end
end
