# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/service'
require 'income_and_assets/benefits_intake/submit_claim_job'
require 'income_and_assets/monitor'
require 'pdf_utilities/datestamp_pdf'

RSpec.describe IncomeAndAssets::BenefitsIntake::SubmitClaimJob, :uploader_helpers do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:income_and_assets_claim) }
  let(:service) { double('service') }
  let(:monitor) { IncomeAndAssets::Monitor.new }
  let(:user_account_uuid) { 123 }
  let(:generated_metadata) do
    {
      'veteranFirstName' => claim.veteran_first_name,
      'veteranLastName' => claim.veteran_last_name,
      'fileNumber' => claim.veteran_filenumber,
      'zipCode' => '00000',
      'source' => job.class.to_s,
      'docType' => claim.form_id,
      'businessLine' => claim.business_line
    }
  end

  describe '#perform' do
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }
    let(:omit_esign_stamp) { true }
    let(:extras_redesign) { true }

    before do
      job.instance_variable_set(:@claim, claim)
      allow(IncomeAndAssets::SavedClaim).to receive(:find).and_return(claim)
      allow(claim).to receive(:to_pdf).with(claim.id, { extras_redesign:, omit_esign_stamp: }).and_return(pdf_path)
      allow(claim).to receive(:persistent_attachments).and_return([])

      job.instance_variable_set(:@intake_service, service)
      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:request_upload)
      allow(service).to receive_messages(location:, perform_upload: response)
      allow(response).to receive(:success?).and_return true

      job.instance_variable_set(:@monitor, monitor)
    end

    it 'submits the saved claim successfully' do
      allow(job).to receive(:process_document).and_return(pdf_path)

      expect(claim).to receive(:to_pdf).with(claim.id, { extras_redesign:, omit_esign_stamp: }).and_return(pdf_path)
      expect(Lighthouse::Submission).to receive(:create)
      expect(Lighthouse::SubmissionAttempt).to receive(:create)
      expect(Datadog::Tracing).to receive(:active_trace)
      expect(UserAccount).to receive(:find)

      expect(service).to receive(:perform_upload).with(
        upload_url: 'test_location', document: pdf_path, metadata: generated_metadata.to_json, attachments: []
      )
      expect(job).to receive(:cleanup_file_paths)

      job.perform(claim.id, :user_account_uuid)
    end

    it 'is unable to find user_account' do
      expect(IncomeAndAssets::SavedClaim).not_to receive(:find)
      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        ActiveRecord::RecordNotFound,
        /Couldn't find UserAccount/
      )
    end

    it 'is unable to find saved_claim_id' do
      allow(IncomeAndAssets::SavedClaim).to receive(:find).and_return(nil)

      expect(UserAccount).to receive(:find)

      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        IncomeAndAssets::BenefitsIntake::SubmitClaimJob::IncomeAndAssetsBenefitIntakeError,
        "Unable to find IncomeAndAssets::SavedClaim #{claim.id}"
      )
    end
    # perform
  end

  describe '#process_document' do
    let(:service) { double('service') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:stamp_pdf_double) { instance_double(IncomeAndAssets::PDFStamper) }

    before do
      job.instance_variable_set(:@intake_service, service)
      job.instance_variable_set(:@claim, claim)
    end

    it 'returns a datestamp pdf path' do
      allow(IncomeAndAssets::PDFStamper).to receive(:new).and_return(stamp_pdf_double)

      expect(stamp_pdf_double).to receive(:run).with('test/path', timestamp: claim.created_at)
      expect(service).to receive(:valid_document?).and_return(pdf_path)

      new_path = job.send(:process_document, 'test/path', :test)

      expect(new_path).to eq(pdf_path)
    end

    it 'successfully stamps the generated pdf' do
      expect(service).to receive(:valid_document?).and_return(pdf_path)
      new_path = job.send(:process_document, claim.to_pdf, :income_and_assets_generated_claim)
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

      allow(IncomeAndAssets::NotificationEmail).to receive(:new).and_return(notification)
      allow(notification).to receive(:deliver).and_raise(monitor_error)

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_send_email_failure)
    end

    it 'errors and logs but does not reraise' do
      expect(IncomeAndAssets::NotificationEmail).to receive(:new).with(claim.id)
      expect(notification).to receive(:deliver).with(:submitted)
      expect(monitor).to receive(:track_send_email_failure)
      job.send(:send_submitted_email)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    let(:exhaustion_msg) do
      { 'args' => [], 'class' => 'IncomeAndAssets::BenefitsIntake::SubmitClaimJob',
        'error_message' => 'An error occurred', 'queue' => 'low' }
    end

    before do
      allow(IncomeAndAssets::Monitor).to receive(:new).and_return(monitor)
    end

    context 'when retries are exhausted' do
      it 'logs a distrinct error when no claim_id provided' do
        IncomeAndAssets::BenefitsIntake::SubmitClaimJob.within_sidekiq_retries_exhausted_block do
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end

      it 'logs a distrinct error when only claim_id provided' do
        IncomeAndAssets::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
          allow(IncomeAndAssets::SavedClaim).to receive(:find).and_return(claim)
          expect(IncomeAndAssets::SavedClaim).to receive(:find).with(claim.id)

          exhaustion_msg['args'] = [claim.id]

          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distrinct error when claim_id and user_account_uuid provided' do
        IncomeAndAssets::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, 2] }) do
          allow(IncomeAndAssets::SavedClaim).to receive(:find).and_return(claim)
          expect(IncomeAndAssets::SavedClaim).to receive(:find).with(claim.id)

          exhaustion_msg['args'] = [claim.id, 2]

          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distrinct error when claim is not found' do
        IncomeAndAssets::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1, 2] }) do
          expect(IncomeAndAssets::SavedClaim).to receive(:find).with(claim.id - 1)

          exhaustion_msg['args'] = [claim.id - 1, 2]

          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end
    end
  end

  # Rspec.describe
end
