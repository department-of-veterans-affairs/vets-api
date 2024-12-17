# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'lighthouse/document_upload'
require 'va_notify/service'
require 'lighthouse/benefits_documents/constants'

RSpec.describe Lighthouse::DocumentUpload, type: :job do
  subject(:job) do
    described_class.perform_async(user_icn,
                                  document_data.to_serializable_hash,
                                  user_account_uuid, claim_id,
                                  tracked_item_ids)
  end

  let(:client_stub) { instance_double(BenefitsDocuments::WorkerService) }
  let(:notify_client_stub) { instance_double(VaNotify::Service) }
  let(:uploader_stub) { instance_double(LighthouseDocumentUploader) }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:filename) { 'doctors-note.pdf' }
  let(:file) { Rails.root.join('spec', 'fixtures', 'files', filename).read }
  let(:user_icn) { user_account.icn }
  let(:tracked_item_ids) { '1234' }
  let(:document_type) { 'L029' }
  let(:password) { 'Password_123' }
  let(:claim_id) { '4567' }
  let(:job_class) { 'Lighthouse::DocumentUpload' }
  let(:document_data) do
    LighthouseDocument.new(
      first_name: 'First Name',
      participant_id: '1111',
      claim_id: claim_id,
      # file_obj: file,
      uuid: SecureRandom.uuid,
      file_extension: 'pdf',
      file_name: filename,
      tracked_item_id: tracked_item_ids,
      document_type:
    )
  end
  let(:response) do
    {
      data: {
        success: true,
        requestId: '12345678'
      }
    }
  end
  let(:failure_response) do
    {
      data: {
        success: false
      }
    }
  end

  let(:issue_instant) { Time.now.to_i }
  let(:args) do
    {
      'args' => [user_account.icn, { 'file_name' => filename, 'first_name' => 'Bob' }],
      'created_at' => issue_instant,
      'failed_at' => issue_instant
    }
  end
  let(:tags) { described_class::DD_ZSF_TAGS }

  before do
    allow(Rails.logger).to receive(:info)
    allow(StatsD).to receive(:increment)
  end

  context 'when cst_send_evidence_failure_emails is enabled' do
    before do
      Flipper.enable(:cst_send_evidence_failure_emails)
      allow(Lighthouse::FailureNotification).to receive(:perform_async)
    end

    let(:job_id) { job }
    let(:evidence_submission_stub) do
      evidence_submission = EvidenceSubmission.new(claim_id: '4567',
                                                   tracked_item_id: tracked_item_ids,
                                                   job_id: job_id,
                                                   job_class: described_class,
                                                   upload_status: 'pending')
      evidence_submission.user_account = user_account
      evidence_submission.save!
      evidence_submission
    end

    let(:formatted_submit_date) do
      # We want to return all times in EDT
      timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

      # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
      timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    end

    it 'calls Lighthouse::FailureNotification' do
      subject.within_sidekiq_retries_exhausted_block(args) do
        expect(Lighthouse::FailureNotification).to receive(:perform_async).with(
          user_account.icn,
          'Bob', # first_name
          'docXXXX-XXte.pdf', # filename
          formatted_submit_date, # date_submitted
          formatted_submit_date # date_failed
        )

        expect(Rails.logger)
          .to receive(:info)
          .with('Lighthouse::DocumentUpload exhaustion handler email queued')
        expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation', tags:)
      end
    end

    it 'retrieves the file and uploads to Lighthouse' do
      allow(LighthouseDocumentUploader).to receive(:new) { uploader_stub }
      allow(BenefitsDocuments::WorkerService).to receive(:new) { client_stub }
      allow(uploader_stub).to receive(:retrieve_from_store!).with(filename) { file }
      allow(uploader_stub).to receive(:read_for_upload) { file }
      allow(client_stub).to receive(:upload_document).with(file, document_data)
      expect(uploader_stub).to receive(:remove!).once
      expect(client_stub).to receive(:upload_document).with(file, document_data).and_return(response)
      allow(EvidenceSubmission).to receive(:find_or_create_by)
        .with({ claim_id:,
                tracked_item_id: tracked_item_ids,
                job_id:,
                job_class:,
                upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING] })
        .and_return(evidence_submission_stub)
      described_class.drain # runs all queued jobs of this class
      # After running DocumentUpload job, there should be a new EvidenceSubmission record
      # with the response request_id
      expect(EvidenceSubmission.find_by(job_id: job_id).request_id).to eql(response.dig(:data, :requestId))
    end

    it 'raises an error when Lighthouse returns a failure response' do
      allow(client_stub).to receive(:upload_document).with(file, document_data).and_return(failure_response)
      expect do
        job
        described_class.drain
      end.to raise_error(StandardError)
    end
  end

  context 'when cst_send_evidence_failure_emails is disabled' do
    before do
      Flipper.disable(:cst_send_evidence_failure_emails)
    end

    let(:issue_instant) { Time.now.to_i }

    it 'does not call Lighthouse::Failure Notification' do
      subject.within_sidekiq_retries_exhausted_block(args) do
        expect(Lighthouse::FailureNotification).not_to receive(:perform_async)
      end
    end
  end
end
