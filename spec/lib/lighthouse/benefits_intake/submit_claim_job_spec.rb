# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/benefits_intake/sidekiq/submit_claim_job'

RSpec.describe BenefitsIntake::SubmitClaimJob, :uploader_helpers do
  stub_virus_scan

  let(:job) { described_class.new }
  let(:claim) { create(:fake_saved_claim) }
  let(:monitor) { double('monitor') }
  let(:response) { double('response') }
  let(:stamper) { double('stamper') }
  let(:service) { double('service', uuid: SecureRandom.uuid, location:) }
  let(:user_account) { double('user_account', id: SecureRandom.uuid, icn: 'FOOBAR') }
  let(:pdf_path) { 'random/path/to/pdf' }
  let(:location) { 'test_location' }

  before do
    allow(BenefitsIntake::Monitor).to receive(:new).and_return(monitor)
  end

  describe '#perform' do
    it 'submits the saved claim successfully' do
      expect(BenefitsIntake::Monitor).to receive(:new).and_return(monitor)

      expect(UserAccount).to receive(:find_by).and_return(user_account)

      expect(SavedClaim).to receive(:find_by).and_return(claim)
      expect(claim).to receive(:to_pdf).and_return(pdf_path)
      expect(claim).to receive(:persistent_attachments).and_return([])

      expect(BenefitsIntake::Service).to receive(:new).and_return(service)

      expect(PDFUtilities::PDFStamper).to receive(:new).and_return(stamper)
      expect(stamper).to receive(:run).with(pdf_path, timestamp: claim.created_at)

      expect(service).to receive(:valid_document?).and_return(pdf_path)

      metadata = { foobar: 'test' }
      expect(BenefitsIntake::Metadata).to receive(:generate).and_return(metadata)

      expect(monitor).to receive(:track_submission_begun).with(claim, service, user_account.id)
      expect(service).to receive(:request_upload)

      expect(Lighthouse::Submission).to receive(:create)
      expect(Lighthouse::SubmissionAttempt).to receive(:create)
      expect(Datadog::Tracing).to receive(:active_trace)

      expect(service).to receive(:location).and_return(location)

      payload = {
        upload_url: location,
        document: pdf_path,
        metadata: metadata.to_json,
        attachments: []
      }
      expect(monitor).to receive(:track_submission_attempted).with(claim, service, user_account.id, payload)
      expect(service).to receive(:perform_upload).with(**payload).and_return(response)

      expect(response).to receive(:success?).and_return true

      expect(Kafka).to receive(:submit_event)

      expect(claim).to receive(:send_email).with(:submitted)
      expect(monitor).to receive(:track_submission_success).with(claim, service, user_account.id)

      expect(job).to receive(:cleanup_file_paths).and_call_original

      config = {
        user_account_uuid: user_account.id,
        email_type: :submitted,
        submit_kafka_event: true,
        attachment_stamp_set: 'test'
      }
      benefits_intake_uuid = job.perform(claim.id, **config)
      expect(benefits_intake_uuid).to eq service.uuid
      expect(job.send(:attachment_stamp_set)).to eq 'test'
    end

    it 'is unable to find user_account' do
      expect(SavedClaim).not_to receive(:find_by)
      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)
      expect(BenefitsIntake::SubmitClaimJob).to receive(:exhaustion)

      job.perform(claim.id, user_account_uuid: 'invalid-user-account-uuid')
    end

    it 'is unable to find saved_claim_id' do
      allow(SavedClaim).to receive(:find_by).and_return(nil)

      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)
      expect(BenefitsIntake::SubmitClaimJob).to receive(:exhaustion)

      job.perform(claim.id)
    end

    it 'raises a runtime error' do
      expect(SavedClaim).to receive(:find_by).and_return(claim)

      expect(BenefitsIntake::Service).to receive(:new).and_raise(service.uuid)

      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id) }.to raise_error(RuntimeError, service.uuid)
    end
  end

  describe '#send_claim_email' do
    before do
      job.instance_variable_set(:@claim, claim)
      job.instance_variable_set(:@config, { email_type: :submitted })
    end

    it 'errors and logs but does not reraise' do
      allow(claim).to receive(:send_email).with(:submitted).and_raise
      expect(monitor).to receive(:track_send_email_failure)
      job.send(:send_claim_email)
    end
  end

  describe '#cleanup_file_paths' do
    before do
      job.instance_variable_set(:@form_path, pdf_path)
      job.instance_variable_set(:@attachment_paths, '/invalid_path/should_be_an_array.failure')
    end

    it 'errors and logs but does not reraise' do
      expect(BenefitsIntake::Monitor).to receive(:new).and_return(monitor)
      expect(monitor).to receive(:track_file_cleanup_error)

      job.send(:cleanup_file_paths)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    let(:exhaustion_msg) do
      { 'args' => [], 'class' => 'BenefitsIntake::SubmitClaimJob',
        'error_message' => 'An error occurred', 'queue' => 'low' }
    end

    context 'when retries are exhausted' do
      it 'logs a distrinct error when no claim_id provided' do
        BenefitsIntake::SubmitClaimJob.within_sidekiq_retries_exhausted_block do
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end

      it 'logs a distrinct error when only claim_id provided' do
        BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
            expect(SavedClaim).to receive(:find_by).with(id: claim.id).and_return(claim)

            exhaustion_msg['args'] = [claim.id]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distrinct error when claim_id and user_account_uuid provided' do
        BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, { user_account_uuid: 2 }] }) do
            expect(SavedClaim).to receive(:find_by).with(id: claim.id).and_return(claim)

            exhaustion_msg['args'] = [claim.id, { user_account_uuid: 2 }]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distrinct error when claim is not found' do
        BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1] }) do
            expect(SavedClaim).to receive(:find_by).with(id: claim.id - 1)

            exhaustion_msg['args'] = [claim.id - 1]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end
    end
  end
end
